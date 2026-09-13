-- 0001_phase1_rls.sql
-- pgTAP tests for Phase 1 identity/access RLS.
-- Run with: supabase test db
-- These are a release gate (Architecture Doc Section 15/18.4), not optional extras.

begin;
select plan(10);

-- ── Fixtures ────────────────────────────────────────────────────────────────
-- Two fake auth users, simulated directly in auth.users for test purposes.
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'admin@test.local'),
  ('22222222-2222-2222-2222-222222222222', 'member@test.local');

-- Promote the first user to admin (trigger already gave both a 'member' role + profile).
insert into public.user_roles (user_id, role_id)
select '11111111-1111-1111-1111-111111111111', id from public.roles where code = 'admin'
on conflict do nothing;

-- ── Test 1: profile auto-provisioning worked ─────────────────────────────────
select is(
  (select count(*)::int from public.users_profile
    where id in ('11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222')),
  2,
  'both auth.users got an auto-provisioned users_profile row'
);

-- ── Test 2: default role is member, not admin, for the second user ──────────
select is(
  (select r.code from public.user_roles ur join public.roles r on r.id = ur.role_id
    where ur.user_id = '22222222-2222-2222-2222-222222222222' and r.code = 'member'),
  'member',
  'new signups default to the member role, never elevated automatically'
);

-- ── Test 3: a member cannot see another user''s profile ─────────────────────
set local role authenticated;
set local request.jwt.claims = '{"sub":"22222222-2222-2222-2222-222222222222"}';

select is(
  (select count(*)::int from public.users_profile
    where id = '11111111-1111-1111-1111-111111111111'),
  0,
  'member role cannot SELECT another user''s profile'
);

-- ── Test 4: a member CAN see their own profile ───────────────────────────────
select is(
  (select count(*)::int from public.users_profile
    where id = '22222222-2222-2222-2222-222222222222'),
  1,
  'member role can SELECT their own profile'
);

-- ── Test 5: a member cannot insert into user_roles (privilege escalation attempt) ──
select throws_ok(
  $$ insert into public.user_roles (user_id, role_id)
     select '22222222-2222-2222-2222-222222222222', id from public.roles where code = 'admin' $$,
  'new row violates row-level security policy for table "user_roles"',
  'member role cannot self-assign the admin role'
);

-- ── Test 6: a member cannot update system_settings ───────────────────────────
select throws_ok(
  $$ update public.system_settings set currency = 'USD' $$,
  'new row violates row-level security policy%',
  'member role cannot modify system_settings'
);

-- ── Test 7: a member cannot read the audit log ───────────────────────────────
select is(
  (select count(*)::int from public.audit_log),
  0,
  'member role has no visibility into audit_log'
);

-- ── Switch to admin ───────────────────────────────────────────────────────────
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

-- ── Test 8: admin CAN see another user''s profile ────────────────────────────
select is(
  (select count(*)::int from public.users_profile
    where id = '22222222-2222-2222-2222-222222222222'),
  1,
  'admin role can SELECT any user profile'
);

-- ── Test 9: admin CAN update system_settings ─────────────────────────────────
select lives_ok(
  $$ update public.system_settings set currency = 'MAD' $$,
  'admin role can modify system_settings'
);

-- ── Test 10: admin CAN read the audit log and sees prior actions ────────────
select ok(
  (select count(*)::int from public.audit_log) > 0,
  'admin role can read audit_log and prior actions were captured'
);

select * from finish();
rollback;
