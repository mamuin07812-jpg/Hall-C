-- Close the identity-binding gap: a student ID alone is not proof of ownership.
-- Requires an enabled roster row with the same verified Firebase email claim.
begin;

alter table schoolivia.approved_students
  add column if not exists email text;

do $$
begin
  if exists (
    select lower(trim(email))
    from schoolivia.approved_students
    where enabled and email is not null
    group by lower(trim(email))
    having count(*) > 1
  ) then
    raise exception 'Cannot enforce unique enabled roster email: duplicates exist';
  end if;
end
$$;

create unique index if not exists approved_students_enabled_email_key
  on schoolivia.approved_students (lower(trim(email)))
  where enabled and email is not null;

create or replace function schoolivia.register_student(
  p_first_name text,
  p_father_name text,
  p_grandfather_name text,
  p_great_grandfather_name text,
  p_student_id text
)
returns uuid
language plpgsql
security definer
set search_path = schoolivia, pg_temp
as $$
declare
  claims jsonb := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  v_uid text := schoolivia.jwt_uid();
  v_email text := lower(trim(claims ->> 'email'));
  v_student_id text := nullif(trim(p_student_id), '');
  v_profile_id uuid;
  v_profile_student_id text;
  v_profile_role schoolivia.account_role;
  v_roster schoolivia.approved_students%rowtype;
begin
  if v_uid is null or not schoolivia.jwt_context_ok() then
    raise exception 'verified Firebase identity required';
  end if;
  if claims ->> 'email_verified' is distinct from 'true' then
    raise exception 'verified Firebase email required';
  end if;
  if v_student_id is null or v_email is null or v_email = '' then
    raise exception 'approved student ID and verified email required';
  end if;

  select * into v_roster
  from schoolivia.approved_students
  where university_id = v_student_id and enabled
    and lower(trim(email)) = v_email
  for share;
  if not found then raise exception 'verified identity does not match the enabled approval roster'; end if;

  select id, role, student_id
    into v_profile_id, v_profile_role, v_profile_student_id
  from schoolivia.profiles
  where firebase_uid = v_uid
  for update;
  if found then
    if v_profile_role <> 'student' or v_profile_student_id is distinct from v_student_id then
      raise exception 'Firebase identity is already linked to a different profile';
    end if;
    return v_profile_id;
  end if;

  insert into schoolivia.profiles (
    firebase_uid, role, first_name, father_name, grandfather_name,
    great_grandfather_name, full_name, email, student_id,
    department, stage, hall, email_verified, email_verified_at,
    registration_status, profile_completed
  ) values (
    v_uid, 'student', nullif(trim(p_first_name), ''),
    nullif(trim(p_father_name), ''), nullif(trim(p_grandfather_name), ''),
    nullif(trim(p_great_grandfather_name), ''),
    v_roster.full_name, v_email,
    v_roster.university_id, v_roster.department, v_roster.stage, v_roster.hall,
    true, now(), 'academic_pending', false
  )
  on conflict (firebase_uid) do nothing
  returning id into v_profile_id;

  if v_profile_id is not null then return v_profile_id; end if;

  select id, role, student_id
    into v_profile_id, v_profile_role, v_profile_student_id
  from schoolivia.profiles
  where firebase_uid = v_uid;
  if found and v_profile_role = 'student' and v_profile_student_id = v_student_id then
    return v_profile_id;
  end if;

  raise exception 'Firebase identity or approved student ID is already linked';
exception
  when unique_violation then
    raise exception 'Firebase identity or approved student ID is already linked';
end;
$$;

create or replace function schoolivia.import_approved_students(p_rows jsonb)
returns jsonb
language plpgsql
security definer
set search_path = schoolivia, pg_temp
as $$
declare
  v_input_count integer;
  v_unique_count integer;
  v_changed_count integer;
begin
  if not schoolivia.is_admin() then raise exception 'admin required'; end if;
  if jsonb_typeof(p_rows) <> 'array' then raise exception 'roster rows must be a JSON array'; end if;
  v_input_count := jsonb_array_length(p_rows);
  if v_input_count < 1 or v_input_count > 5000 then raise exception 'roster batch size must be 1..5000'; end if;

  if exists (
    select 1 from jsonb_to_recordset(p_rows) as x(
      university_id text, email text, full_name text, department text,
      stage text, hall text, enabled boolean
    )
    where nullif(trim(university_id), '') is null
       or nullif(trim(email), '') is null
       or position('@' in trim(email)) < 2
       or position('.' in split_part(trim(email), '@', 2)) < 2
       or nullif(trim(full_name), '') is null
       or nullif(trim(department), '') is null
       or stage is null or stage not in ('First Stage', 'Second Stage', 'Third Stage', 'Fourth Stage')
       or hall is null or hall not in ('A', 'B', 'C', 'D')
       or enabled is null
  ) then raise exception 'roster contains invalid required fields'; end if;

  select count(distinct lower(trim(x.university_id))) into v_unique_count
  from jsonb_to_recordset(p_rows) as x(
    university_id text, email text, full_name text, department text,
    stage text, hall text, enabled boolean
  );
  if v_unique_count <> v_input_count then raise exception 'roster contains duplicate student IDs'; end if;
  select count(distinct lower(trim(x.email))) into v_unique_count
  from jsonb_to_recordset(p_rows) as x(
    university_id text, email text, full_name text, department text,
    stage text, hall text, enabled boolean
  );
  if v_unique_count <> v_input_count then raise exception 'roster contains duplicate emails'; end if;

  insert into schoolivia.approved_students(university_id, email, full_name, department, stage, hall, enabled)
  select trim(x.university_id), lower(trim(x.email)), trim(x.full_name), trim(x.department),
         x.stage, upper(trim(x.hall)), x.enabled
  from jsonb_to_recordset(p_rows) as x(
    university_id text, email text, full_name text, department text,
    stage text, hall text, enabled boolean
  )
  on conflict (university_id) do update set
    email = excluded.email,
    full_name = excluded.full_name,
    department = excluded.department,
    stage = excluded.stage,
    hall = excluded.hall,
    enabled = excluded.enabled,
    updated_at = now();
  get diagnostics v_changed_count = row_count;

  -- Disabling an already-linked roster entry immediately deactivates its
  -- profile. Re-enabling a roster row never silently unblocks an account.
  update schoolivia.profiles p
  set blocked = true,
      blocked_at = coalesce(p.blocked_at, now()),
      blocked_by = coalesce(p.blocked_by, schoolivia.current_profile_id()),
      updated_at = now()
  where p.role = 'student'
    and p.student_id in (
      select x.university_id
      from jsonb_to_recordset(p_rows) as x(
        university_id text, email text, full_name text, department text,
        stage text, hall text, enabled boolean
      )
      where x.enabled = false
    );

  return jsonb_build_object('received', v_input_count, 'written', v_changed_count);
end;
$$;

insert into schoolivia_internal.schema_migrations(version)
values ('004_verified_roster_email_binding')
on conflict (version) do nothing;

commit;
