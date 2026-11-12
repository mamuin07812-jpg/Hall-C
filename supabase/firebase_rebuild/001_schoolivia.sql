-- Evidence-led Firebase-compatible Schoolivia schema. Empty install; no Firebase data imported.
begin;
-- This migration also runs against a plain PostgreSQL test database. Keep
-- pgcrypto in the schema used by the SECURITY DEFINER routines below.
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
do $$ begin
 if to_regprocedure('extensions.digest(bytea,text)') is null then
  alter extension pgcrypto set schema extensions;
 end if;
end $$;
create schema if not exists schoolivia_internal;
revoke all on schema schoolivia_internal from public,anon,authenticated,service_role;
create table if not exists schoolivia_internal.schema_migrations (
 version text primary key,
 applied_at timestamptz not null default now()
);
revoke all on table schoolivia_internal.schema_migrations from public,anon,authenticated,service_role;
create schema if not exists schoolivia;
revoke all on schema schoolivia from public, anon;
grant usage on schema schoolivia to authenticated, service_role;

create type schoolivia.account_role as enum ('admin','teacher','student');
create type schoolivia.teacher_status as enum ('pending','approved','rejected');
create type schoolivia.registration_status as enum ('academic_pending','complete','not_registered');
create type schoolivia.change_status as enum ('pending','approved','rejected');
create type schoolivia.library_kind as enum ('curriculum','handout');

create function schoolivia.touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

-- Firebase UID is the external immutable identifier; UUID is a local relational key.
create table schoolivia.profiles (
 id uuid primary key default gen_random_uuid(), firebase_uid text not null unique,
 role schoolivia.account_role not null, first_name text, father_name text, grandfather_name text,
 great_grandfather_name text, family_name text, full_name text, email text, student_id text,
 employee_id text, department text, stage text, hall text check (hall is null or hall in ('A','B','C','D')),
 specialization text, subject text, gender text, profile_image text,
 email_verified boolean not null default false, email_verified_at timestamptz,
 registration_status schoolivia.registration_status,
 profile_completed boolean not null default false,
 teacher_status schoolivia.teacher_status,
 blocked boolean not null default false, blocked_at timestamptz, blocked_by uuid references schoolivia.profiles(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check ((role='teacher') = (teacher_status is not null)),
 check (stage is null or stage in ('First Stage','Second Stage','Third Stage','Fourth Stage','First','Second','Third','Fourth','1','2','3','4'))
);
create index profiles_cohort_idx on schoolivia.profiles(department,stage,hall) where role='student';
create index profiles_teacher_lookup_idx on schoolivia.profiles(specialization,department) where role='teacher';

create table schoolivia.approved_students (
 university_id text primary key, full_name text not null, department text not null,
 stage text not null check (stage in ('First Stage','Second Stage','Third Stage','Fourth Stage')),
 hall text not null check (hall in ('A','B','C','D')), enabled boolean not null default true,
 registration_status schoolivia.registration_status not null default 'not_registered',
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table schoolivia.representative_assignments (
 id uuid primary key default gen_random_uuid(), student_id uuid not null references schoolivia.profiles(id),
 hall text not null check (hall in ('A','B','C','D')), student_name text, active boolean not null default true,
 assigned_by uuid references schoolivia.profiles(id), updated_by uuid references schoolivia.profiles(id),
 replaced_by uuid references schoolivia.profiles(id), revoked_by uuid references schoolivia.profiles(id),
 assigned_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check (not active or student_id is not null)
);
create unique index one_active_rep_per_hall on schoolivia.representative_assignments(hall) where active;
create unique index one_active_hall_per_rep on schoolivia.representative_assignments(student_id) where active;

create table schoolivia.schedules (
 id uuid primary key default gen_random_uuid(), source_id text unique, department text, stage text, hall text,
 subject text, course text, title text, name text, day text, day_ar text, start_time time, end_time time,
 teacher_id uuid references schoolivia.profiles(id), teacher_name text, teacher text, professor text, instructor text, lecturer text, schedule_key text,
 teacher_schedule_source_id text, audience_halls text[] not null default '{}', legacy_days jsonb, lectures jsonb,
 display_order integer, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check (hall is null or hall in ('A','B','C','D','ALL')),
 check (start_time is null or end_time is null or start_time < end_time),
 check (audience_halls <@ array['A','B','C','D']::text[])
);
create index schedules_cohort_idx on schoolivia.schedules(department,stage,hall,day,start_time);
create index schedules_teacher_idx on schoolivia.schedules(teacher_id,day,start_time);

create table schoolivia.preparations (
 id uuid primary key default gen_random_uuid(), source_id text unique, subject text not null, professor text, teacher_name text,
 content text, teacher_id uuid references schoolivia.profiles(id), creator_id uuid references schoolivia.profiles(id),
 last_editor_id uuid references schoolivia.profiles(id), last_editor_type text, assignment_schedule_ids jsonb,
 creator_type text not null default 'legacy' check (creator_type in ('legacy','admin','teacher','representative')),
 publisher_name text, specialization text, department text not null, stage text not null, hall text,
 visible_to_halls text[] not null default '{}', department_key text, stage_key text,
 pdf_path text, pdf_url text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check (hall is null or hall in ('A','B','C','D','ALL')),
 check (visible_to_halls <@ array['A','B','C','D']::text[])
);
create index preparations_audience_idx on schoolivia.preparations using gin(visible_to_halls);
create index preparations_scope_idx on schoolivia.preparations(department_key,stage_key,created_at desc);
create index preparations_creator_idx on schoolivia.preparations(creator_id,created_at desc);

create table schoolivia.announcements (
 id uuid primary key default gen_random_uuid(), source_id text unique, title text not null, content text not null,
 created_by uuid references schoolivia.profiles(id), target text not null default 'all', target_group text, department text, target_stage text,
 is_active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check (target_group is null or target_group='' or target_group in ('A','B','C','D','ALL'))
);
create index announcements_feed_idx on schoolivia.announcements(is_active,created_at desc);

create table schoolivia.notifications (
 id uuid primary key default gen_random_uuid(), source_id text unique, title text not null, body text not null,
 type text, target text, target_group text, department text, stage text,
 created_by uuid references schoolivia.profiles(id), created_at timestamptz not null default now()
);
create index notifications_audience_idx on schoolivia.notifications(target_group,type,created_at desc);
create table schoolivia.notification_tokens (
 token text primary key, user_id uuid not null references schoolivia.profiles(id) on delete cascade,
 platform text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index notification_tokens_user_idx on schoolivia.notification_tokens(user_id);
-- Outbox-compatible state records for existing delivery semantics; no trigger/dispatcher enabled here.
create table schoolivia.notification_delivery_events (
 event_id text primary key, status text not null check (status in ('processing','retryable','sent','expired','invalid_target','no_recipients','awaiting_tokens','completed_with_failures')),
 attempts integer not null default 0 check (attempts >= 0), started_at timestamptz,
 lease_until timestamptz, expires_at timestamptz, expired_at timestamptz, failed_at timestamptz,
 completed_at timestamptz, eligible_uids jsonb, payload jsonb,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table schoolivia.notification_delivery_devices (
 event_id text not null references schoolivia.notification_delivery_events(event_id) on delete cascade,
 token_hash text not null, status text not null check (status in ('accepted','retryable','invalid','permanent_failure')), accepted_at timestamptz, updated_at timestamptz not null default now(),
 primary key(event_id,token_hash)
);

create table schoolivia.app_updates (
 id text primary key, version text, version_name text, build integer, version_code integer,
 apk_url text, package_url text, notes text, force_update boolean not null default false,
 sha256 text, package_sha256 text, checksum text, size_bytes bigint check (size_bytes is null or size_bytes>=0),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table schoolivia.academic_change_requests (
 id uuid primary key default gen_random_uuid(), source_id text unique,
 student_id uuid not null references schoolivia.profiles(id), student_name text, student_email text,
 department text, current_stage text, current_hall text, requested_stage text, requested_hall text,
 status schoolivia.change_status not null default 'pending', approved_stage text, approved_hall text,
 reviewed_by uuid references schoolivia.profiles(id), reviewed_at timestamptz, approved_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check (current_hall is null or current_hall in ('A','B','C','D')),
 check (requested_hall is null or requested_hall in ('A','B','C','D'))
);
create index academic_requests_owner_idx on schoolivia.academic_change_requests(student_id,created_at desc);
create table schoolivia.academic_change_attachments (
 id uuid primary key default gen_random_uuid(), request_id uuid not null references schoolivia.academic_change_requests(id) on delete cascade,
 storage_path text not null, source_url text, created_at timestamptz not null default now(), unique(request_id,storage_path)
);

create table schoolivia.library_items (
 id uuid primary key default gen_random_uuid(), source_id text unique, kind schoolivia.library_kind not null,
 name text not null, author_or_teacher text, pdf_url text, storage_path text,
 created_by uuid references schoolivia.profiles(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index library_kind_created_idx on schoolivia.library_items(kind,created_at desc);

create function schoolivia.jwt_context_ok() returns boolean language sql stable as $$
 select coalesce(
   nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'iss' = 'https://securetoken.google.com/com-example-hallc-93786'
   and nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'aud' = 'com-example-hallc-93786'
   and nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'role' = 'authenticated'
   and nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'sub' <> '', false) $$;
create function schoolivia.jwt_uid() returns text language sql stable set search_path=schoolivia,pg_temp as $$
 select case when schoolivia.jwt_context_ok() then nullif(current_setting('request.jwt.claims',true)::jsonb->>'sub','') end $$;
create function schoolivia.current_profile_id() returns uuid language sql stable security definer
 set search_path=schoolivia,pg_temp as $$ select id from profiles where firebase_uid=jwt_uid() limit 1 $$;
create function schoolivia.is_admin() returns boolean language sql stable security definer
 set search_path=schoolivia,pg_temp as $$ select exists(select 1 from profiles where id=current_profile_id() and role='admin' and not blocked) $$;
create function schoolivia.is_approved_teacher() returns boolean language sql stable security definer
 set search_path=schoolivia,pg_temp as $$ select exists(select 1 from profiles where id=current_profile_id() and role='teacher' and teacher_status='approved' and not blocked) $$;
create function schoolivia.is_active_representative() returns boolean language sql stable security definer
 set search_path=schoolivia,pg_temp as $$ select exists(select 1 from representative_assignments a join profiles p on p.id=a.student_id where a.active and p.id=current_profile_id() and p.role='student' and p.profile_completed and p.email_verified and not p.blocked and p.hall=a.hall) $$;
create function schoolivia.normalize_hall(v text) returns text language sql immutable as $$
 select case when upper(trim(coalesce(v,'')))='ALL' then 'ALL' when upper(trim(coalesce(v,''))) ~ '[A-D]$' then substring(upper(trim(v)) from '([A-D])$') else upper(trim(coalesce(v,''))) end $$;
create function schoolivia.normalize_stage(v text) returns text language sql immutable as $$
 select case lower(trim(coalesce(v,''))) when 'first' then 'first stage' when '1' then 'first stage' when 'first stage' then 'first stage' when 'second' then 'second stage' when '2' then 'second stage' when 'second stage' then 'second stage' when 'third' then 'third stage' when '3' then 'third stage' when 'third stage' then 'third stage' when 'fourth' then 'fourth stage' when '4' then 'fourth stage' when 'fourth stage' then 'fourth stage' else lower(trim(coalesce(v,''))) end $$;
create function schoolivia.normalize_department(v text) returns text language sql immutable as $$
 select case when lower(trim(coalesce(v,''))) like '%english%' then 'english language department' else lower(trim(coalesce(v,''))) end $$;
create function schoolivia.normalize_day(v text) returns text language sql immutable as $$
 select case lower(trim(coalesce(v,'')))
  when 'sunday' then U&'\0627\0644\0623\062D\062F' when 'monday' then U&'\0627\0644\0627\062B\0646\064A\0646'
  when 'tuesday' then U&'\0627\0644\062B\0644\0627\062B\0627\0621' when 'wednesday' then U&'\0627\0644\0623\0631\0628\0639\0627\0621'
  when 'thursday' then U&'\0627\0644\062E\0645\064A\0633' when 'friday' then U&'\0627\0644\062C\0645\0639\0629' when 'saturday' then U&'\0627\0644\0633\0628\062A'
  else case when trim(coalesce(v,'')) in (U&'\0627\0644\0623\062D\062F',U&'\0627\0644\0627\062B\0646\064A\0646',U&'\0627\0644\062B\0644\0627\062B\0627\0621',U&'\0627\0644\0623\0631\0628\0639\0627\0621',U&'\0627\0644\062E\0645\064A\0633',U&'\0627\0644\062C\0645\0639\0629',U&'\0627\0644\0633\0628\062A') then trim(v) else null end end $$;

-- Expose schema only to signed-in JWTs. Identity issuer/audience must additionally be checked by PostgREST/gateway config.
grant select,insert,update,delete on all tables in schema schoolivia to authenticated;
do $$ declare t text; begin
 for t in select tablename from pg_tables where schemaname='schoolivia' loop
  execute format('alter table schoolivia.%I enable row level security',t);
  execute format('create policy authenticated_identity on schoolivia.%I as restrictive for all to authenticated using (schoolivia.jwt_context_ok()) with check (schoolivia.jwt_context_ok())',t);
 end loop;
end $$;

create policy profiles_read on schoolivia.profiles for select to authenticated using
 (schoolivia.is_admin() or id=schoolivia.current_profile_id());
-- Profile writes are RPC-only. Column and lifecycle rules are enforced in the functions below.
create policy approved_students_admin on schoolivia.approved_students for all to authenticated using (schoolivia.is_admin()) with check (schoolivia.is_admin());
create policy representative_read on schoolivia.representative_assignments for select to authenticated using
 (schoolivia.is_admin() or student_id=schoolivia.current_profile_id() or
 (active and hall=(select requester.hall from schoolivia.profiles requester where requester.id=schoolivia.current_profile_id() and requester.role='student' and requester.profile_completed and requester.email_verified and not requester.blocked) and
 exists(select 1 from schoolivia.profiles peer where peer.id=schoolivia.representative_assignments.student_id and peer.role='student' and peer.profile_completed and peer.email_verified and not peer.blocked and peer.hall=schoolivia.representative_assignments.hall)));
-- Assignment mutations are RPC-only, which serializes replacement/revocation and validates hall ownership.
create policy schedules_read on schoolivia.schedules for select to authenticated using
 (schoolivia.is_admin() or (schoolivia.is_approved_teacher() and teacher_id=schoolivia.current_profile_id()) or
 (exists(select 1 from schoolivia.profiles p where p.id=schoolivia.current_profile_id() and p.role='student' and not p.blocked and p.profile_completed and schoolivia.normalize_department(p.department)=schoolivia.normalize_department(schedules.department) and schoolivia.normalize_stage(p.stage)=schoolivia.normalize_stage(schedules.stage) and (schoolivia.normalize_hall(p.hall)=schoolivia.normalize_hall(schedules.hall) or schedules.hall='ALL'))));
create policy schedules_admin_write on schoolivia.schedules for all to authenticated using (schoolivia.is_admin()) with check (schoolivia.is_admin());
create policy preparations_read on schoolivia.preparations for select to authenticated using
 (schoolivia.is_admin() or (schoolivia.is_approved_teacher() and (teacher_id=schoolivia.current_profile_id() or specialization=(select specialization from schoolivia.profiles where id=schoolivia.current_profile_id()))) or
 (creator_id=schoolivia.current_profile_id() and not exists(select 1 from schoolivia.profiles p where p.id=schoolivia.current_profile_id() and p.blocked)) or exists(select 1 from schoolivia.profiles p where p.id=schoolivia.current_profile_id() and p.role='student' and p.profile_completed and not p.blocked and schoolivia.normalize_department(p.department)=schoolivia.normalize_department(preparations.department) and schoolivia.normalize_stage(p.stage)=schoolivia.normalize_stage(preparations.stage) and schoolivia.normalize_hall(p.hall)=any(preparations.visible_to_halls)));
-- Preparation mutation is RPC-only so authorship, audience, immutable identity, and file paths are checked together.
create policy announcements_read on schoolivia.announcements for select to authenticated using
 (schoolivia.is_admin() or (schoolivia.is_approved_teacher() and (created_by=schoolivia.current_profile_id() or (coalesce(target_group,'')='' and coalesce(department,'')='' and coalesce(target_stage,'')=''))) or exists(select 1 from schoolivia.profiles u where u.id=schoolivia.current_profile_id() and u.role='student' and u.profile_completed and not u.blocked and is_active and (target_group is null or target_group='' or schoolivia.normalize_hall(target_group)='ALL' or schoolivia.normalize_hall(target_group)=schoolivia.normalize_hall(u.hall)) and (department is null or department='' or schoolivia.normalize_department(department)=schoolivia.normalize_department(u.department)) and (target_stage is null or target_stage='' or schoolivia.normalize_stage(target_stage)=schoolivia.normalize_stage(u.stage))));
create policy announcements_admin_write on schoolivia.announcements for all to authenticated using (schoolivia.is_admin()) with check (schoolivia.is_admin());
create policy announcements_teacher_write on schoolivia.announcements for all to authenticated using (created_by=schoolivia.current_profile_id() and schoolivia.is_approved_teacher()) with check (created_by=schoolivia.current_profile_id() and schoolivia.is_approved_teacher());
create policy notifications_read on schoolivia.notifications for select to authenticated using (schoolivia.is_admin() or exists(select 1 from schoolivia.profiles u where u.id=schoolivia.current_profile_id() and not u.blocked and (u.role='student' and u.profile_completed or u.role='teacher' and u.teacher_status='approved') and (target_group is null or target_group='' or schoolivia.normalize_hall(target_group)='ALL' or schoolivia.normalize_hall(target_group)=schoolivia.normalize_hall(u.hall)) and (department is null or department='' or schoolivia.normalize_department(department)=schoolivia.normalize_department(u.department)) and (stage is null or stage='' or schoolivia.normalize_stage(stage)=schoolivia.normalize_stage(u.stage)) and (target is null or trim(target)='' or lower(trim(target))='all' or target=u.firebase_uid or upper(trim(target))='GROUP:'||schoolivia.normalize_hall(u.hall))));
create policy notifications_admin_write on schoolivia.notifications for all to authenticated using (schoolivia.is_admin()) with check (schoolivia.is_admin());
create policy notifications_teacher_insert on schoolivia.notifications for insert to authenticated with check (schoolivia.is_approved_teacher() and created_by=schoolivia.current_profile_id());
create policy notifications_rep_insert on schoolivia.notifications for insert to authenticated with check (schoolivia.is_active_representative() and created_by=schoolivia.current_profile_id() and type='preparation' and target='all' and schoolivia.normalize_hall(target_group)=(select a.hall from schoolivia.representative_assignments a where a.student_id=schoolivia.current_profile_id() and a.active) and (department is null or schoolivia.normalize_department(department)=(select schoolivia.normalize_department(p.department) from schoolivia.profiles p where p.id=schoolivia.current_profile_id())) and (stage is null or schoolivia.normalize_stage(stage)=(select schoolivia.normalize_stage(p.stage) from schoolivia.profiles p where p.id=schoolivia.current_profile_id())));
create policy tokens_owner on schoolivia.notification_tokens for all to authenticated using (user_id=schoolivia.current_profile_id() and exists(select 1 from schoolivia.profiles p where p.id=user_id and not p.blocked)) with check (user_id=schoolivia.current_profile_id() and exists(select 1 from schoolivia.profiles p where p.id=user_id and not p.blocked));
create policy tokens_admin_read on schoolivia.notification_tokens for select to authenticated using (schoolivia.is_admin());
-- Delivery state is backend-only. No authenticated client can read tokens' delivery status.
create policy app_updates_read on schoolivia.app_updates for select to authenticated using (true);
create policy app_updates_admin_write on schoolivia.app_updates for all to authenticated using (schoolivia.is_admin()) with check (schoolivia.is_admin());
create policy requests_read on schoolivia.academic_change_requests for select to authenticated using (schoolivia.is_admin() or student_id=schoolivia.current_profile_id());
create policy requests_student_insert on schoolivia.academic_change_requests for insert to authenticated with check (student_id=schoolivia.current_profile_id() and status='pending' and exists(select 1 from schoolivia.profiles p where p.id=schoolivia.current_profile_id() and p.role='student' and not p.blocked));
create policy requests_admin_write on schoolivia.academic_change_requests for all to authenticated using (schoolivia.is_admin()) with check (schoolivia.is_admin());
create policy request_attachments_read on schoolivia.academic_change_attachments for select to authenticated using (schoolivia.is_admin() or exists(select 1 from schoolivia.academic_change_requests r where r.id=request_id and r.student_id=schoolivia.current_profile_id()));
create policy request_attachments_insert on schoolivia.academic_change_attachments for insert to authenticated with check (storage_path like ('academic-change-requests/'||(select firebase_uid from schoolivia.profiles where id=schoolivia.current_profile_id())||'/%') and exists(select 1 from schoolivia.academic_change_requests r where r.id=request_id and r.student_id=schoolivia.current_profile_id() and r.status='pending'));
create policy request_attachments_admin_write on schoolivia.academic_change_attachments for all to authenticated using (schoolivia.is_admin()) with check (schoolivia.is_admin());
create policy library_read on schoolivia.library_items for select to authenticated using (schoolivia.is_admin() or exists(select 1 from schoolivia.profiles p where p.id=schoolivia.current_profile_id() and p.role='student' and p.profile_completed and not p.blocked));
create policy library_admin_write on schoolivia.library_items for all to authenticated using (schoolivia.is_admin()) with check (schoolivia.is_admin());

create function schoolivia.assign_representative(p_student uuid,p_hall text) returns void language plpgsql security definer set search_path=schoolivia,pg_temp as $$
declare target profiles;
begin
 if not is_admin() then raise exception 'admin required'; end if;
 select * into target from profiles where id=p_student for update;
 if p_hall not in ('A','B','C','D') or not found or target.role<>'student' or not target.profile_completed or not target.email_verified or target.blocked or target.hall<>p_hall then raise exception 'student must be active and assigned to the same hall'; end if;
 perform pg_advisory_xact_lock(hashtext(p_hall));
 update representative_assignments set active=false,replaced_by=p_student,updated_by=current_profile_id(),updated_at=now() where hall=p_hall and active;
 update representative_assignments set active=false,revoked_by=current_profile_id(),updated_at=now() where student_id=p_student and active;
 insert into representative_assignments(student_id,hall,student_name,assigned_by,updated_by) select id,hall,coalesce(full_name,concat_ws(' ',first_name,father_name,grandfather_name,family_name)),current_profile_id(),current_profile_id() from profiles where id=p_student;
end $$;
create function schoolivia.revoke_representative(p_student uuid) returns void language plpgsql security definer set search_path=schoolivia,pg_temp as $$
begin if not is_admin() then raise exception 'admin required'; end if; perform 1 from profiles where id=p_student for update; update representative_assignments set active=false,revoked_by=current_profile_id(),updated_by=current_profile_id(),updated_at=now() where student_id=p_student and active; end $$;

create function schoolivia.review_academic_change(p_request uuid,p_decision schoolivia.change_status,p_stage text default null,p_hall text default null) returns void language plpgsql security definer set search_path=schoolivia,pg_temp as $$
declare r academic_change_requests; begin
 if not is_admin() or p_decision='pending' then raise exception 'invalid decision'; end if;
 select * into r from academic_change_requests where id=p_request for update;
 if not found or r.status<>'pending' then raise exception 'request not pending'; end if;
 if not exists(select 1 from profiles where id=r.student_id and role='student') then raise exception 'request owner is not a student'; end if;
 update academic_change_requests set status=p_decision,approved_stage=case when p_decision='approved' then coalesce(p_stage,r.requested_stage) end,approved_hall=case when p_decision='approved' then coalesce(p_hall,r.requested_hall) end,reviewed_by=current_profile_id(),reviewed_at=now(),approved_at=case when p_decision='approved' then now() end,updated_at=now() where id=p_request;
 if p_decision='approved' then update profiles set stage=coalesce(p_stage,r.requested_stage),hall=coalesce(p_hall,r.requested_hall),updated_at=now() where id=r.student_id; end if;
end $$;
create function schoolivia.admin_delete_academic_change(p_request uuid) returns void language plpgsql security definer set search_path=schoolivia,pg_temp as $$
begin if not is_admin() then raise exception 'admin required'; end if; delete from academic_change_requests where id=p_request; end $$;

-- Firebase UID comes only from the verified request JWT. Role is selected by this operation, never caller input.
create function schoolivia.register_student(p_first_name text,p_father_name text,p_grandfather_name text,p_great_grandfather_name text,p_student_id text)
returns uuid language plpgsql security definer set search_path=schoolivia,pg_temp as $$
declare v_uid text:=jwt_uid(); v_email text; v_id uuid;
begin
 if v_uid is null or not jwt_context_ok() then raise exception 'verified Firebase identity required'; end if;
 v_email:=nullif(current_setting('request.jwt.claims',true)::jsonb->>'email','');
 if v_email is null then raise exception 'verified account email required'; end if;
 if exists(select 1 from profiles where firebase_uid=v_uid) then raise exception 'profile already exists'; end if;
 insert into profiles(firebase_uid,role,first_name,father_name,grandfather_name,great_grandfather_name,family_name,full_name,email,student_id,department,email_verified,email_verified_at,registration_status,profile_completed)
 values(v_uid,'student',nullif(trim(p_first_name),''),nullif(trim(p_father_name),''),nullif(trim(p_grandfather_name),''),nullif(trim(p_great_grandfather_name),''),nullif(trim(p_great_grandfather_name),''),concat_ws(' ',nullif(trim(p_first_name),''),nullif(trim(p_father_name),''),nullif(trim(p_grandfather_name),''),nullif(trim(p_great_grandfather_name),'')),v_email,nullif(trim(p_student_id),''),'English Language',true,now(),'academic_pending',false)
 returning id into v_id; return v_id;
end $$;

create function schoolivia.register_teacher(p_name text,p_employee_id text,p_specialization text)
returns uuid language plpgsql security definer set search_path=schoolivia,pg_temp as $$
declare v_uid text:=jwt_uid(); v_email text; v_id uuid;
begin
 if v_uid is null or not jwt_context_ok() then raise exception 'verified Firebase identity required'; end if;
 v_email:=nullif(current_setting('request.jwt.claims',true)::jsonb->>'email','');
 if v_email is null then raise exception 'account email required'; end if;
 if exists(select 1 from profiles where firebase_uid=v_uid) then raise exception 'profile already exists'; end if;
 if nullif(trim(p_name),'') is null or nullif(trim(p_employee_id),'') is null or p_specialization not in ('Poetry','Conversation','Guidance','Theology','Teaching Methods','Drama','Linguistics','Grammar','Academic Writing','Novel') then raise exception 'invalid teacher registration'; end if;
 insert into profiles(firebase_uid,role,full_name,email,employee_id,specialization,department,email_verified,email_verified_at,teacher_status)
 values(v_uid,'teacher',trim(p_name),v_email,trim(p_employee_id),p_specialization,'English Language',true,now(),'pending') returning id into v_id; return v_id;
end $$;

create function schoolivia.complete_student_registration(p_gender text,p_stage text,p_hall text)
returns void language plpgsql security definer set search_path=schoolivia,pg_temp as $$
begin
 if not jwt_context_ok() or not exists(select 1 from profiles where id=current_profile_id() and role='student' and email_verified and not blocked and not profile_completed and registration_status='academic_pending') then raise exception 'eligible incomplete student required'; end if;
 if p_gender not in ('male','female','ذكر','أنثى') or p_stage not in ('First Stage','Second Stage','Third Stage','Fourth Stage','First','Second','Third','Fourth','1','2','3','4') or p_hall not in ('A','B','C','D') then raise exception 'invalid academic profile'; end if;
 update profiles set gender=p_gender,department='English Language',stage=p_stage,hall=p_hall,profile_completed=true,registration_status='complete',updated_at=now() where id=current_profile_id();
end $$;

create function schoolivia.update_own_profile(p_first_name text default null,p_father_name text default null,p_grandfather_name text default null,p_family_name text default null,p_gender text default null,p_profile_image text default null)
returns void language plpgsql security definer set search_path=schoolivia,pg_temp as $$
declare p profiles;
begin
 if not jwt_context_ok() then raise exception 'verified Firebase identity required'; end if;
 select * into p from profiles where id=current_profile_id();
 if p.id is null or p.blocked then raise exception 'active profile required'; end if;
 if p.role='teacher' and (p_first_name is not null or p_father_name is not null or p_grandfather_name is not null or p_family_name is not null or p_gender is not null) then raise exception 'teachers may only update profile image'; end if;
 if p.role='admin' then raise exception 'admin profile changes require server administration'; end if;
 update profiles set first_name=coalesce(nullif(trim(p_first_name),''),first_name),father_name=coalesce(nullif(trim(p_father_name),''),father_name),grandfather_name=coalesce(nullif(trim(p_grandfather_name),''),grandfather_name),family_name=coalesce(nullif(trim(p_family_name),''),family_name),full_name=coalesce(nullif(concat_ws(' ',nullif(trim(p_first_name),''),nullif(trim(p_father_name),''),nullif(trim(p_grandfather_name),''),nullif(trim(p_family_name),'')),''),full_name),gender=coalesce(p_gender,gender),profile_image=coalesce(p_profile_image,profile_image),updated_at=now() where id=current_profile_id();
end $$;

create function schoolivia.admin_set_teacher_status(p_teacher uuid,p_status schoolivia.teacher_status)
returns void language plpgsql security definer set search_path=schoolivia,pg_temp as $$
begin if not is_admin() or p_status is null then raise exception 'admin required and valid status'; end if; update profiles set teacher_status=p_status,updated_at=now() where id=p_teacher and role='teacher'; if not found then raise exception 'teacher profile not found'; end if; end $$;
create function schoolivia.admin_set_blocked(p_user uuid,p_blocked boolean)
returns void language plpgsql security definer set search_path=schoolivia,pg_temp as $$
begin if not is_admin() then raise exception 'admin required'; end if; update profiles set blocked=p_blocked,blocked_at=case when p_blocked then now() else null end,blocked_by=case when p_blocked then current_profile_id() else null end,updated_at=now() where id=p_user and role<>'admin'; if not found then raise exception 'non-admin profile not found'; end if; end $$;

create function schoolivia.save_teacher_schedule_lecture(p_source_id text,p_halls text[],p_subject text,p_day text,p_start time,p_end time)
returns void language plpgsql security definer set search_path=schoolivia,pg_temp as $$
declare s schedules; h text; sid text;
begin
 if not is_approved_teacher() then raise exception 'approved teacher required'; end if;
 select * into s from schedules where source_id=p_source_id for update;
 if not found or s.teacher_id<>current_profile_id() then raise exception 'only assigned lectures may be edited'; end if;
 if p_halls is null or cardinality(p_halls)<1 or cardinality(p_halls)>4 or not (p_halls <@ array['A','B','C','D']::text[]) or cardinality(p_halls)<>(select count(distinct x) from unnest(p_halls) x) or p_subject is null or length(trim(p_subject)) not between 1 and 160 or schoolivia.normalize_day(p_day) is null or p_start is null or p_end is null or p_end<=p_start then raise exception 'invalid lecture data'; end if;
 if cardinality(p_halls)>1 and not (p_halls @> array['A','B','C','D']::text[]) then raise exception 'select one hall or all halls'; end if;
 -- Reject a deterministic sibling ID owned by another schedule or teacher.
 foreach h in array array['A','B','C','D'] loop
  sid:=case when h=p_halls[1] then p_source_id else 'teacher_'||substr(encode(extensions.digest(convert_to(p_source_id,'UTF8'),'sha256'),'hex'),1,32)||'_'||h end;
  if exists(select 1 from schedules x where x.source_id=sid and (x.teacher_id is distinct from current_profile_id() or (h<>p_halls[1] and x.teacher_schedule_source_id is distinct from p_source_id))) then raise exception 'schedule record conflict'; end if;
 end loop;
 if exists(select 1 from schedules x where x.teacher_schedule_source_id=p_source_id and x.teacher_id is distinct from current_profile_id()) then raise exception 'lecture has a hall record owned by another account'; end if;
 delete from schedules x where x.teacher_schedule_source_id=p_source_id and not (x.hall=any(p_halls));
 foreach h in array p_halls loop
  sid:=case when h=p_halls[1] then p_source_id else 'teacher_'||substr(encode(extensions.digest(convert_to(p_source_id,'UTF8'),'sha256'),'hex'),1,32)||'_'||h end;
  insert into schedules(source_id,department,stage,hall,subject,day,day_ar,start_time,end_time,teacher_id,teacher_name,teacher,professor,instructor,lecturer,schedule_key,teacher_schedule_source_id,audience_halls,created_at,updated_at)
  values(sid,s.department,s.stage,h,trim(p_subject),p_day,schoolivia.normalize_day(p_day),p_start,p_end,current_profile_id(),coalesce((select full_name from profiles where id=current_profile_id()),s.teacher_name),coalesce((select full_name from profiles where id=current_profile_id()),s.teacher),coalesce((select full_name from profiles where id=current_profile_id()),s.professor),coalesce((select full_name from profiles where id=current_profile_id()),s.instructor),coalesce((select full_name from profiles where id=current_profile_id()),s.lecturer),s.schedule_key,case when h=p_halls[1] then s.teacher_schedule_source_id else p_source_id end,array[h],now(),now())
  on conflict(source_id) do update set department=excluded.department,stage=excluded.stage,hall=excluded.hall,subject=excluded.subject,day=excluded.day,day_ar=excluded.day_ar,start_time=excluded.start_time,end_time=excluded.end_time,teacher_id=excluded.teacher_id,teacher_name=excluded.teacher_name,teacher=excluded.teacher,professor=excluded.professor,instructor=excluded.instructor,lecturer=excluded.lecturer,teacher_schedule_source_id=excluded.teacher_schedule_source_id,audience_halls=excluded.audience_halls,updated_at=now();
 end loop;
end $$;

create function schoolivia.create_preparation(p_subject text,p_content text,p_department text,p_stage text,p_halls text[],p_pdf_path text default null,p_pdf_url text default null)
returns uuid language plpgsql security definer set search_path=schoolivia,pg_temp as $$
declare v_id uuid; p profiles; v_type text;
begin
 select * into p from profiles where id=current_profile_id();
 if p.id is null or p.blocked or p_department is null or p_stage is null or cardinality(p_halls)<1 or not (p_halls <@ array['A','B','C','D']::text[]) then raise exception 'invalid author or audience'; end if;
 if p.role='teacher' and p.teacher_status='approved' and p.department=p_department and (p.specialization is not null) then v_type:='teacher';
 elsif p.role='student' and is_active_representative() and p.department=p_department and p.stage=p_stage and cardinality(p_halls)=1 and p.hall=p_halls[1] then v_type:='representative';
 elsif is_admin() then v_type:='admin';
 else raise exception 'author is not permitted to publish this preparation'; end if;
 insert into preparations(subject,professor,teacher_name,content,teacher_id,creator_id,last_editor_id,last_editor_type,creator_type,publisher_name,specialization,department,stage,hall,visible_to_halls,department_key,stage_key,pdf_path,pdf_url)
 values(trim(p_subject),p.full_name,p.full_name,p_content,case when v_type='teacher' then p.id end,p.id,p.id,v_type,v_type,p.full_name,p.specialization,p_department,p_stage,case when cardinality(p_halls)=1 then p_halls[1] else 'ALL' end,p_halls,lower(p_department),lower(p_stage),p_pdf_path,p_pdf_url) returning id into v_id;
 return v_id;
end $$;

create function schoolivia.edit_preparation(p_id uuid,p_content text,p_pdf_path text default null,p_pdf_url text default null,p_department text default null,p_stage text default null,p_halls text[] default null)
returns void language plpgsql security definer set search_path=schoolivia,pg_temp as $$
declare x preparations; p profiles;
begin
 select * into x from preparations where id=p_id for update; if not found then raise exception 'preparation not found'; end if;
 select * into p from profiles where id=current_profile_id();
 if is_admin() then update preparations set content=p_content,pdf_path=p_pdf_path,pdf_url=p_pdf_url,department=coalesce(p_department,department),stage=coalesce(p_stage,stage),visible_to_halls=coalesce(p_halls,visible_to_halls),hall=case when p_halls is null then hall when cardinality(p_halls)=1 then p_halls[1] else 'ALL' end,department_key=coalesce(lower(p_department),department_key),stage_key=coalesce(lower(p_stage),stage_key),last_editor_id=current_profile_id(),last_editor_type='admin' where id=p_id; return; end if;
 if x.creator_id<>p.id or p.blocked then raise exception 'not preparation owner'; end if;
 if x.creator_type='teacher' and p.role='teacher' and p.teacher_status='approved' and x.teacher_id=p.id and x.specialization=p.specialization then
  if p_department is not null and p_department<>p.department then raise exception 'department outside teacher scope'; end if;
  if p_halls is not null and (cardinality(p_halls)<1 or not (p_halls <@ array['A','B','C','D']::text[])) then raise exception 'invalid audience'; end if;
  update preparations set content=p_content,pdf_path=p_pdf_path,pdf_url=p_pdf_url,department=coalesce(p_department,department),stage=coalesce(p_stage,stage),visible_to_halls=coalesce(p_halls,visible_to_halls),hall=case when p_halls is null then hall when cardinality(p_halls)=1 then p_halls[1] else 'ALL' end,last_editor_id=current_profile_id(),last_editor_type='teacher' where id=p_id;
 elsif x.creator_type='representative' and is_active_representative() and p.hall=any(x.visible_to_halls) then
  if p_department is not null and p_department<>x.department or p_stage is not null and p_stage<>x.stage or p_halls is not null and p_halls<>x.visible_to_halls then raise exception 'representative audience is fixed to assigned hall'; end if;
  update preparations set content=p_content,pdf_path=p_pdf_path,pdf_url=p_pdf_url,last_editor_id=current_profile_id(),last_editor_type='representative' where id=p_id;
 else raise exception 'not permitted to edit preparation'; end if;
end $$;
create function schoolivia.admin_update_preparation(p_id uuid,p_subject text,p_professor text,p_teacher_name text,p_publisher_name text,p_content text,p_teacher_id uuid,p_creator_id uuid,p_creator_type text,p_specialization text,p_department text,p_stage text,p_halls text[],p_assignment_schedule_ids jsonb,p_pdf_path text,p_pdf_url text)
returns void language plpgsql security definer set search_path=schoolivia,pg_temp as $$
begin
 if not is_admin() then raise exception 'admin required'; end if;
 if p_subject is null or trim(p_subject)='' or p_department is null or p_stage is null or p_creator_type not in ('legacy','admin','teacher','representative') or p_halls is null or cardinality(p_halls)<1 or not (p_halls <@ array['A','B','C','D']::text[]) then raise exception 'invalid preparation fields'; end if;
 update preparations set subject=trim(p_subject),professor=p_professor,teacher_name=p_teacher_name,content=p_content,teacher_id=p_teacher_id,creator_id=p_creator_id,last_editor_id=current_profile_id(),last_editor_type='admin',creator_type=p_creator_type,publisher_name=p_publisher_name,specialization=p_specialization,department=p_department,stage=p_stage,hall=case when cardinality(p_halls)=1 then p_halls[1] else 'ALL' end,visible_to_halls=p_halls,department_key=lower(p_department),stage_key=lower(p_stage),assignment_schedule_ids=p_assignment_schedule_ids,pdf_path=p_pdf_path,pdf_url=p_pdf_url,updated_at=now() where id=p_id;
 if not found then raise exception 'preparation not found'; end if;
end $$;
create function schoolivia.delete_preparation(p_id uuid) returns void language plpgsql security definer set search_path=schoolivia,pg_temp as $$
declare x preparations; p profiles; begin select * into x from preparations where id=p_id for update; if not found then return; end if; select * into p from profiles where id=current_profile_id(); if not is_admin() and (x.creator_id<>current_profile_id() or p.blocked or (x.creator_type='teacher' and not is_approved_teacher()) or (x.creator_type='representative' and (not is_active_representative() or not p.hall=any(x.visible_to_halls)))) then raise exception 'not permitted to delete preparation'; end if; delete from preparations where id=p_id; end $$;

-- Never permit direct edits to identity/lifecycle/assignment/preparation/delivery rows.
revoke insert,update,delete on schoolivia.profiles,schoolivia.representative_assignments,schoolivia.preparations,schoolivia.notification_delivery_events,schoolivia.notification_delivery_devices from authenticated;
revoke update,delete on schoolivia.academic_change_requests from authenticated;
grant all privileges on all tables in schema schoolivia to service_role;
grant usage,select on all sequences in schema schoolivia to service_role;
grant execute on function schoolivia.register_student(text,text,text,text,text),schoolivia.register_teacher(text,text,text),schoolivia.complete_student_registration(text,text,text),schoolivia.update_own_profile(text,text,text,text,text,text),schoolivia.admin_set_teacher_status(uuid,schoolivia.teacher_status),schoolivia.admin_set_blocked(uuid,boolean),schoolivia.save_teacher_schedule_lecture(text,text[],text,text,time,time),schoolivia.create_preparation(text,text,text,text,text[],text,text),schoolivia.edit_preparation(uuid,text,text,text,text,text,text[]),schoolivia.admin_update_preparation(uuid,text,text,text,text,text,uuid,uuid,text,text,text,text,text[],jsonb,text,text),schoolivia.delete_preparation(uuid),schoolivia.assign_representative(uuid,text),schoolivia.revoke_representative(uuid),schoolivia.review_academic_change(uuid,schoolivia.change_status,text,text),schoolivia.admin_delete_academic_change(uuid) to authenticated;

-- Storage objects remain separate from relational rows. Private buckets mirror the existing Worker naming.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
 ('schoolivia-preparations','schoolivia-preparations',false,null,array['application/pdf']),
 ('schoolivia-library','schoolivia-library',false,52428799,array['application/pdf']),
 ('schoolivia-academic-change-requests','schoolivia-academic-change-requests',false,10485759,array['image/*','application/pdf'])
on conflict(id) do nothing;
grant usage on schema storage to authenticated,service_role;
grant select on storage.buckets to authenticated,service_role;
grant select,insert,update,delete on storage.objects to authenticated,service_role;
create policy schoolivia_prep_storage_read on storage.objects for select to authenticated using
 (bucket_id='schoolivia-preparations' and exists(select 1 from schoolivia.preparations p where p.pdf_path=name));
create policy schoolivia_prep_storage_backend_write on storage.objects for all to service_role using (bucket_id='schoolivia-preparations') with check (bucket_id='schoolivia-preparations');
create policy schoolivia_library_storage_read on storage.objects for select to authenticated using
 (bucket_id='schoolivia-library' and (schoolivia.is_admin() or exists(select 1 from schoolivia.profiles p where p.id=schoolivia.current_profile_id() and p.role='student' and p.profile_completed and not p.blocked and p.stage in ('Third Stage','third stage','Third','third','3'))));
create policy schoolivia_library_storage_backend_write on storage.objects for all to service_role using (bucket_id='schoolivia-library') with check (bucket_id='schoolivia-library');
create policy schoolivia_academic_storage_admin_read on storage.objects for select to authenticated using
 (bucket_id='schoolivia-academic-change-requests' and schoolivia.is_admin());
create policy schoolivia_academic_storage_owner_read on storage.objects for select to authenticated using
 (bucket_id='schoolivia-academic-change-requests' and (storage.foldername(name))[1]='academic-change-requests' and (storage.foldername(name))[2]=(select firebase_uid from schoolivia.profiles where id=schoolivia.current_profile_id() and role='student' and profile_completed));
create policy schoolivia_academic_storage_student_upload on storage.objects for insert to authenticated with check
 (bucket_id='schoolivia-academic-change-requests' and (storage.foldername(name))[1]='academic-change-requests' and (storage.foldername(name))[2]=(select firebase_uid from schoolivia.profiles where id=schoolivia.current_profile_id() and role='student' and profile_completed));

create trigger profiles_updated before update on schoolivia.profiles for each row execute function schoolivia.touch_updated_at();
create trigger approved_students_updated before update on schoolivia.approved_students for each row execute function schoolivia.touch_updated_at();
create trigger schedules_updated before update on schoolivia.schedules for each row execute function schoolivia.touch_updated_at();
create trigger preparations_updated before update on schoolivia.preparations for each row execute function schoolivia.touch_updated_at();
create trigger announcements_updated before update on schoolivia.announcements for each row execute function schoolivia.touch_updated_at();
create trigger tokens_updated before update on schoolivia.notification_tokens for each row execute function schoolivia.touch_updated_at();
create trigger app_updates_updated before update on schoolivia.app_updates for each row execute function schoolivia.touch_updated_at();
create trigger requests_updated before update on schoolivia.academic_change_requests for each row execute function schoolivia.touch_updated_at();
create trigger library_updated before update on schoolivia.library_items for each row execute function schoolivia.touch_updated_at();

insert into schoolivia_internal.schema_migrations(version) values ('001_schoolivia') on conflict (version) do nothing;
commit;
