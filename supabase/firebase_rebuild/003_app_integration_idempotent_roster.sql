-- App integration hardening on top of the established Schoolivia schema.
-- Intended for the isolated schoolivia_app_integration_test_20261110 database.
begin;

do $$
begin
  if exists (
    select student_id
    from schoolivia.profiles
    where role = 'student' and student_id is not null
    group by student_id
    having count(*) > 1
  ) then
    raise exception 'Cannot enforce one profile per approved student ID: duplicates exist';
  end if;
end
$$;

create unique index if not exists profiles_student_id_student_key
  on schoolivia.profiles (student_id)
  where role = 'student' and student_id is not null;

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
  v_uid text := schoolivia.jwt_uid();
  v_email text;
  v_student_id text := nullif(trim(p_student_id), '');
  v_profile_id uuid;
  v_profile_student_id text;
  v_profile_role schoolivia.account_role;
  v_roster schoolivia.approved_students%rowtype;
begin
  -- Fail closed until migration 004 adds and validates an email-bound roster.
  -- The apply script immediately runs 004 after this migration.
  raise exception 'verified roster email binding migration 004 is required';

  if v_uid is null or not schoolivia.jwt_context_ok() then
    raise exception 'verified Firebase identity required';
  end if;
  if v_student_id is null then raise exception 'approved student ID required'; end if;

  v_email := nullif(lower(trim(current_setting('request.jwt.claims', true)::jsonb ->> 'email')), '');
  if v_email is null then raise exception 'verified account email required'; end if;

  select * into v_roster
  from schoolivia.approved_students
  where university_id = v_student_id and enabled
  for share;
  if not found then raise exception 'student is not on the enabled approval roster'; end if;

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
    great_grandfather_name, family_name, full_name, email, student_id,
    department, stage, hall, email_verified, email_verified_at,
    registration_status, profile_completed
  ) values (
    v_uid, 'student', nullif(trim(p_first_name), ''),
    nullif(trim(p_father_name), ''), nullif(trim(p_grandfather_name), ''),
    nullif(trim(p_great_grandfather_name), ''),
    nullif(trim(p_great_grandfather_name), ''), v_roster.full_name, v_email,
    v_roster.university_id, v_roster.department, v_roster.stage, v_roster.hall,
    true, now(), 'academic_pending', false
  )
  on conflict (firebase_uid) do nothing
  returning id into v_profile_id;

  if v_profile_id is not null then return v_profile_id; end if;

  -- A concurrent retry may have inserted the same identity. Return that UUID
  -- only when it is linked to this same roster entry.
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

create or replace function schoolivia.complete_student_registration(
  p_gender text,
  p_stage text,
  p_hall text
)
returns void
language plpgsql
security definer
set search_path = schoolivia, pg_temp
as $$
declare
  p schoolivia.profiles%rowtype;
  r schoolivia.approved_students%rowtype;
begin
  if not schoolivia.jwt_context_ok() then raise exception 'verified Firebase identity required'; end if;
  select * into p from schoolivia.profiles where id = schoolivia.current_profile_id() for update;
  if not found or p.role <> 'student' or p.blocked or not p.email_verified
     or p.profile_completed or p.registration_status <> 'academic_pending' then
    raise exception 'eligible incomplete student required';
  end if;
  select * into r from schoolivia.approved_students
  where university_id = p.student_id and enabled for share;
  if not found then raise exception 'enabled approval roster entry required'; end if;
  if p_gender not in ('male', 'female', U&'\0630\0643\0631', U&'\0623\0646\062B\0649')
     or schoolivia.normalize_stage(p_stage) <> schoolivia.normalize_stage(r.stage)
     or upper(trim(p_hall)) <> upper(trim(r.hall)) then
    raise exception 'registration values must match the approved roster';
  end if;

  update schoolivia.profiles
  set gender = p_gender, department = r.department, stage = r.stage, hall = r.hall,
      profile_completed = true, registration_status = 'complete', updated_at = now()
  where id = p.id;
  update schoolivia.approved_students
  set registration_status = 'complete', updated_at = now()
  where university_id = r.university_id;
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
  raise exception 'verified roster email binding migration 004 is required';

  if not schoolivia.is_admin() then raise exception 'admin required'; end if;
  if jsonb_typeof(p_rows) <> 'array' then raise exception 'roster rows must be a JSON array'; end if;
  v_input_count := jsonb_array_length(p_rows);
  if v_input_count < 1 or v_input_count > 5000 then raise exception 'roster batch size must be 1..5000'; end if;

  if exists (
    select 1 from jsonb_to_recordset(p_rows) as x(
      university_id text, full_name text, department text, stage text, hall text, enabled boolean
    )
    where nullif(trim(university_id), '') is null
       or nullif(trim(full_name), '') is null
       or nullif(trim(department), '') is null
       or stage is null or stage not in ('First Stage', 'Second Stage', 'Third Stage', 'Fourth Stage')
       or hall is null or hall not in ('A', 'B', 'C', 'D')
       or enabled is null
  ) then raise exception 'roster contains invalid required fields'; end if;

  select count(distinct lower(trim(x.university_id))) into v_unique_count
  from jsonb_to_recordset(p_rows) as x(
    university_id text, full_name text, department text, stage text, hall text, enabled boolean
  );
  if v_unique_count <> v_input_count then raise exception 'roster contains duplicate student IDs'; end if;

  insert into schoolivia.approved_students(university_id, full_name, department, stage, hall, enabled)
  select trim(x.university_id), trim(x.full_name), trim(x.department), x.stage, upper(trim(x.hall)), x.enabled
  from jsonb_to_recordset(p_rows) as x(
    university_id text, full_name text, department text, stage text, hall text, enabled boolean
  )
  on conflict (university_id) do update set
    full_name = excluded.full_name,
    department = excluded.department,
    stage = excluded.stage,
    hall = excluded.hall,
    enabled = excluded.enabled,
    updated_at = now();
  get diagnostics v_changed_count = row_count;
  return jsonb_build_object('received', v_input_count, 'written', v_changed_count);
end;
$$;

revoke all on function schoolivia.import_approved_students(jsonb) from public, anon;
grant execute on function schoolivia.import_approved_students(jsonb) to authenticated;

insert into schoolivia_internal.schema_migrations(version)
values ('003_app_integration_idempotent_roster')
on conflict (version) do nothing;

commit;
