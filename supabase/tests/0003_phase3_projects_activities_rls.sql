-- 0003_phase3_projects_activities_rls.sql
-- pgTAP tests for Projects + Activities (Phase 3).
-- Run with: supabase test db

begin;
select plan(9);

-- ── Fixtures (superuser context, RLS not yet applied) ────────────────────────
insert into auth.users (id, email) values
  ('b1111111-1111-1111-1111-111111111111', 'president3@test.local'),
  ('b2222222-2222-2222-2222-222222222222', 'secretary3@test.local'),
  ('b3333333-3333-3333-3333-333333333333', 'plainmember3@test.local');

insert into public.user_roles (user_id, role_id)
select 'b1111111-1111-1111-1111-111111111111', id from public.roles where code = 'president'
on conflict do nothing;

insert into public.user_roles (user_id, role_id)
select 'b2222222-2222-2222-2222-222222222222', id from public.roles where code = 'secretary'
on conflict do nothing;
-- b3333333... keeps only the default 'member' role.

insert into public.members (id, membership_number, full_name, current_status) values
  ('c1111111-1111-1111-1111-111111111111', 'MB-P3-01', 'Linked Member', 'active'),
  ('c2222222-2222-2222-2222-222222222222', 'MB-P3-02', 'Other Member', 'active');

update public.users_profile set member_id = 'c1111111-1111-1111-1111-111111111111'
  where id = 'b3333333-3333-3333-3333-333333333333';

insert into public.projects (id, name, status) values
  ('d1111111-1111-1111-1111-111111111111', 'Project Without Linked Member', 'active'),
  ('d2222222-2222-2222-2222-222222222222', 'Project With Linked Member', 'active');

insert into public.project_responsible (project_id, member_id) values
  ('d1111111-1111-1111-1111-111111111111', 'c2222222-2222-2222-2222-222222222222'),
  ('d2222222-2222-2222-2222-222222222222', 'c1111111-1111-1111-1111-111111111111');

insert into public.activities (id, name, status) values
  ('e1111111-1111-1111-1111-111111111111', 'Activity Without Linked Member', 'planned'),
  ('e2222222-2222-2222-2222-222222222222', 'Activity With Linked Participant', 'planned');

insert into public.activity_participants (activity_id, member_id) values
  ('e2222222-2222-2222-2222-222222222222', 'c1111111-1111-1111-1111-111111111111');

-- ── Secrétaire: projects.read but NOT projects.manage; activities.manage ────
set local role authenticated;
set local request.jwt.claims = '{"sub":"b2222222-2222-2222-2222-222222222222"}';

select is(
  (select count(*)::int from public.projects),
  2,
  'secretary role (projects.read) can see all projects'
);

select throws_ok(
  $$ insert into public.projects (name) values ('Blocked Project') $$,
  'new row violates row-level security policy for table "projects"',
  'secretary role cannot create a project (no projects.manage)'
);

select lives_ok(
  $$ insert into public.activities (name) values ('Secretary-created Activity') $$,
  'secretary role CAN create an activity (has activities.manage)'
);

-- ── Président: has projects.manage ──────────────────────────────────────────
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"b1111111-1111-1111-1111-111111111111"}';

select lives_ok(
  $$ insert into public.projects (name) values ('President-created Project') $$,
  'president role CAN create a project (has projects.manage)'
);

-- ── Plain Membre: no projects.read / activities.read, only their own link ──
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"b3333333-3333-3333-3333-333333333333"}';

select is(
  (select count(*)::int from public.projects where id = 'd1111111-1111-1111-1111-111111111111'),
  0,
  'member-role user cannot see a project they are not responsible for'
);

select is(
  (select count(*)::int from public.projects where id = 'd2222222-2222-2222-2222-222222222222'),
  1,
  'member-role user CAN see a project where they are listed as responsible'
);

select is(
  (select count(*)::int from public.activities where id = 'e1111111-1111-1111-1111-111111111111'),
  0,
  'member-role user cannot see an activity they are not part of'
);

select is(
  (select count(*)::int from public.activities where id = 'e2222222-2222-2222-2222-222222222222'),
  1,
  'member-role user CAN see an activity where they are a registered participant'
);

select throws_ok(
  $$ insert into public.activities (name) values ('Blocked Member Activity') $$,
  'new row violates row-level security policy for table "activities"',
  'member-role user cannot create an activity'
);

select * from finish();
rollback;
