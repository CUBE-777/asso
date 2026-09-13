-- 0002_phase2_members_rls.sql
-- pgTAP tests for the Members module (Phase 2).
-- Run with: supabase test db

begin;
select plan(12);

-- ── Fixtures (run as superuser, before switching role, so RLS doesn't apply yet) ──
insert into auth.users (id, email) values
  ('33333333-3333-3333-3333-333333333333', 'secretary@test.local'),
  ('44444444-4444-4444-4444-444444444444', 'treasurer@test.local'),
  ('55555555-5555-5555-5555-555555555555', 'plainmember@test.local');

insert into public.user_roles (user_id, role_id)
select '33333333-3333-3333-3333-333333333333', id from public.roles where code = 'secretary'
on conflict do nothing;

insert into public.user_roles (user_id, role_id)
select '44444444-4444-4444-4444-444444444444', id from public.roles where code = 'treasurer'
on conflict do nothing;
-- user 555... keeps only its default 'member' role from the signup trigger.

-- Two member records created directly (as superuser) for fixture purposes.
insert into public.members (id, membership_number, full_name, current_status)
values
  ('a1111111-1111-1111-1111-111111111111', 'MB-0001', 'Fatima Zahra', 'active'),
  ('a2222222-2222-2222-2222-222222222222', 'MB-0002', 'Youssef Amrani', 'active');

-- Link the plain member's login to the FIRST member record only.
update public.users_profile
set member_id = 'a1111111-1111-1111-1111-111111111111'
where id = '55555555-5555-5555-5555-555555555555';

-- ── Test 1: creating a member auto-logged an initial status_history row ─────
select is(
  (select count(*)::int from public.member_status_history
    where member_id = 'a1111111-1111-1111-1111-111111111111' and previous_status is null),
  1,
  'inserting a member auto-creates an initial status_history row with null previous_status'
);

-- ── Test 2: changing status appends a new history row with correct previous value ──
update public.members set current_status = 'suspended'
  where id = 'a1111111-1111-1111-1111-111111111111';

select is(
  (select previous_status from public.member_status_history
    where member_id = 'a1111111-1111-1111-1111-111111111111'
    order by changed_at desc limit 1),
  'active',
  'status change is logged with the correct previous_status'
);

-- reset for the RLS tests below
update public.members set current_status = 'active'
  where id = 'a1111111-1111-1111-1111-111111111111';

-- ── Switch to the Secrétaire (members.read + create + update, no delete) ────
set local role authenticated;
set local request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333333"}';

select is(
  (select count(*)::int from public.members),
  2,
  'secretary role can read all member records'
);

select lives_ok(
  $$ insert into public.members (membership_number, full_name)
     values ('MB-0003', 'Test Secretary Insert') $$,
  'secretary role can create a new member'
);

select lives_ok(
  $$ update public.members set phone = '0600000000'
     where id = 'a1111111-1111-1111-1111-111111111111' $$,
  'secretary role can update a member'
);

-- ── Switch to the Trésorier (members.read only, no create/update) ───────────
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"44444444-4444-4444-4444-444444444444"}';

select is(
  (select count(*)::int from public.members),
  3,
  'treasurer role can read member records (view-only per the permission matrix)'
);

select throws_ok(
  $$ insert into public.members (membership_number, full_name) values ('MB-0004', 'Blocked Insert') $$,
  'new row violates row-level security policy for table "members"',
  'treasurer role cannot create a member (view-only)'
);

select throws_ok(
  $$ update public.members set phone = '0611111111' where id = 'a1111111-1111-1111-1111-111111111111' $$,
  'new row violates row-level security policy for table "members"',
  'treasurer role cannot update a member (view-only)'
);

-- ── Switch to the plain Membre linked to member a1111111... ─────────────────
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"55555555-5555-5555-5555-555555555555"}';

select is(
  (select count(*)::int from public.members where id = 'a1111111-1111-1111-1111-111111111111'),
  1,
  'a Membre-role user linked to a member record can see their own member row'
);

select is(
  (select count(*)::int from public.members where id = 'a2222222-2222-2222-2222-222222222222'),
  0,
  'a Membre-role user cannot see a member row that is not their own'
);

select throws_ok(
  $$ update public.members set phone = '0622222222' where id = 'a1111111-1111-1111-1111-111111111111' $$,
  'new row violates row-level security policy for table "members"',
  'a Membre-role user cannot update even their own member record (read-only per matrix)'
);

-- ── Test: no application role can write directly to member_status_history ───
select throws_ok(
  $$ insert into public.member_status_history (member_id, previous_status, new_status)
     values ('a1111111-1111-1111-1111-111111111111', 'active', 'withdrawn') $$,
  'new row violates row-level security policy for table "member_status_history"',
  'no application role can write member_status_history directly (trigger-only)'
);

select * from finish();
rollback;
