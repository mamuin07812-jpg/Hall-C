-- Test integration migration: require a server-signed OTP proof claim before
-- creating a new student profile. Apply only to an isolated test database.
begin;

create table if not exists schoolivia_internal.otp_proof_uses (
  jti text primary key,
  firebase_uid text not null,
  email text not null,
  expires_at timestamptz not null,
  consumed_at timestamptz not null default now()
);
revoke all on table schoolivia_internal.otp_proof_uses
  from public, anon, authenticated, service_role;

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
set search_path = schoolivia, schoolivia_internal, pg_temp
as $$
declare
  claims jsonb := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  v_uid text := schoolivia.jwt_uid();
  v_email text := lower(trim(claims ->> 'email'));
  v_student_id text := nullif(trim(p_student_id), '');
  v_jti text := nullif(trim(claims ->> 'otp_jti'), '');
  v_exp bigint;
  v_now bigint := floor(extract(epoch from now()))::bigint;
  v_profile_id uuid;
  v_profile_student_id text;
  v_profile_role schoolivia.account_role;
  v_roster schoolivia.approved_students%rowtype;
begin
  if v_uid is null or not schoolivia.jwt_context_ok() then
    raise exception 'verified Firebase identity required';
  end if;
  if v_student_id is null or v_email is null or v_email = '' then
    raise exception 'approved student ID and email required';
  end if;

  select * into v_roster
  from schoolivia.approved_students
  where university_id = v_student_id and enabled
    and lower(trim(email)) = v_email
  for share;
  if not found then raise exception 'identity does not match the enabled approval roster'; end if;

  -- Same identity/roster retries remain idempotent after proof consumption.
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

  if claims ->> 'otp_verified' is distinct from 'true'
     or lower(trim(claims ->> 'otp_email')) is distinct from v_email
     or claims ->> 'otp_uid' is distinct from v_uid
     or claims ->> 'otp_purpose' is distinct from 'student.register'
     or v_jti is null then
    raise exception 'trusted OTP verification required';
  end if;
  begin
    v_exp := (claims ->> 'otp_exp')::bigint;
  exception when others then
    raise exception 'invalid OTP proof expiry';
  end;
  if v_exp <= v_now or v_exp > v_now + 300 then
    raise exception 'OTP proof expired or exceeds maximum lifetime';
  end if;

  insert into schoolivia_internal.otp_proof_uses(jti, firebase_uid, email, expires_at)
  values(v_jti, v_uid, v_email, to_timestamp(v_exp))
  on conflict (jti) do nothing;
  if not found then raise exception 'OTP proof already used'; end if;

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
  raise exception 'Firebase identity or approved student ID is already linked';
exception
  when unique_violation then
    raise exception 'Firebase identity or approved student ID is already linked';
end;
$$;

-- Keep the Flutter form's title-case gender values while pinning academic
-- stage and hall to the approved roster row established during enrollment.
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
  if not schoolivia.jwt_context_ok() then
    raise exception 'verified Firebase identity required';
  end if;

  select * into p
  from schoolivia.profiles
  where id = schoolivia.current_profile_id()
  for update;
  if not found or p.role <> 'student' or p.blocked or not p.email_verified
     or p.profile_completed or p.registration_status <> 'academic_pending' then
    raise exception 'eligible incomplete student required';
  end if;

  select * into r
  from schoolivia.approved_students
  where university_id = p.student_id and enabled
    and lower(trim(email)) = lower(trim(p.email))
  for share;
  if not found then raise exception 'enabled matching approval roster entry required'; end if;

  if p_gender not in ('Male', 'Female', 'male', 'female', U&'\0630\0643\0631', U&'\0623\0646\062B\0649')
     or schoolivia.normalize_stage(p_stage) <> schoolivia.normalize_stage(r.stage)
     or upper(trim(p_hall)) <> upper(trim(r.hall)) then
    raise exception 'registration values must match the approved roster';
  end if;

  update schoolivia.profiles
  set gender = p_gender, department = r.department, stage = r.stage, hall = r.hall,
      profile_completed = true, registration_status = 'complete', updated_at = now()
  where id = p.id;
end;
$$;

-- Test-only hardening for the existing teacher signup RPC. Keep its signature,
-- input validation, pending approval state, and Firebase identity flow intact.
create or replace function schoolivia.register_teacher(
  p_name text,
  p_employee_id text,
  p_specialization text
)
returns uuid
language plpgsql
security definer
set search_path = schoolivia, schoolivia_internal, pg_temp
as $$
declare
  claims jsonb := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  v_uid text := schoolivia.jwt_uid();
  v_email text := lower(trim(claims ->> 'email'));
  v_jti text := nullif(trim(claims ->> 'otp_jti'), '');
  v_exp bigint;
  v_now bigint := floor(extract(epoch from now()))::bigint;
  v_id uuid;
begin
  if v_uid is null or not schoolivia.jwt_context_ok() then
    raise exception 'verified Firebase identity required';
  end if;
  if v_email is null or v_email = '' then
    raise exception 'account email required';
  end if;
  if exists(select 1 from schoolivia.profiles where firebase_uid = v_uid) then
    raise exception 'profile already exists';
  end if;
  if nullif(trim(p_name), '') is null
     or nullif(trim(p_employee_id), '') is null
     or p_specialization not in ('Poetry','Conversation','Guidance','Theology','Teaching Methods','Drama','Linguistics','Grammar','Academic Writing','Novel') then
    raise exception 'invalid teacher registration';
  end if;
  if claims ->> 'otp_verified' is distinct from 'true'
     or lower(trim(claims ->> 'otp_email')) is distinct from v_email
     or claims ->> 'otp_uid' is distinct from v_uid
     or claims ->> 'otp_purpose' is distinct from 'teacher.register'
     or v_jti is null then
    raise exception 'trusted OTP verification required';
  end if;
  begin
    v_exp := (claims ->> 'otp_exp')::bigint;
  exception when others then
    raise exception 'invalid OTP proof expiry';
  end;
  if v_exp <= v_now or v_exp > v_now + 300 then
    raise exception 'OTP proof expired or exceeds maximum lifetime';
  end if;

  insert into schoolivia_internal.otp_proof_uses(jti, firebase_uid, email, expires_at)
  values(v_jti, v_uid, v_email, to_timestamp(v_exp))
  on conflict (jti) do nothing;
  if not found then raise exception 'OTP proof already used'; end if;

  insert into schoolivia.profiles(
    firebase_uid, role, full_name, email, employee_id, specialization,
    department, email_verified, email_verified_at, teacher_status
  ) values (
    v_uid, 'teacher', trim(p_name), v_email, trim(p_employee_id),
    p_specialization, 'English Language', true, now(), 'pending'
  ) returning id into v_id;
  return v_id;
exception
  when unique_violation then
    raise exception 'Firebase identity or employee ID is already linked';
end;
$$;

insert into schoolivia_internal.schema_migrations(version)
values ('005_otp_proof_registration_test')
on conflict (version) do nothing;

commit;
