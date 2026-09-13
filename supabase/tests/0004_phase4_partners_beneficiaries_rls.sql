-- 0004_phase4_partners_beneficiaries_rls.sql
begin;
select plan(6);

insert into auth.users (id, email) values
  ('f1111111-1111-1111-1111-111111111111', 'president4@test.local'),
  ('f2222222-2222-2222-2222-222222222222', 'secretary4@test.local');

insert into public.user_roles (user_id, role_id)
select 'f1111111-1111-1111-1111-111111111111', id from public.roles where code = 'president'
on conflict do nothing;
insert into public.user_roles (user_id, role_id)
select 'f2222222-2222-2222-2222-222222222222', id from public.roles where code = 'secretary'
on conflict do nothing;

-- Temporarily grant secretary base beneficiaries.read (but NOT .sensitive) to
-- prove the separation actually matters, since no seeded role currently holds
-- read-without-sensitive together.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r, public.permissions p
where r.code = 'secretary' and p.code = 'beneficiaries.read'
on conflict do nothing;

insert into public.beneficiary_categories (code, label_ar, label_fr, label_en) values
  ('family', 'أسرة', 'Famille', 'Family');

insert into public.beneficiaries (id, category_id, display_name)
select 'g1111111-1111-1111-1111-111111111111', id, 'BEN-0001'
from public.beneficiary_categories where code = 'family';

insert into public.beneficiary_sensitive (beneficiary_id, full_name, phone)
values ('g1111111-1111-1111-1111-111111111111', 'Real Name Redacted', '0600000000');

-- ── Secrétaire: base beneficiaries.read only ────────────────────────────────
set local role authenticated;
set local request.jwt.claims = '{"sub":"f2222222-2222-2222-2222-222222222222"}';

select is(
  (select count(*)::int from public.beneficiaries where id = 'g1111111-1111-1111-1111-111111111111'),
  1,
  'secretary with beneficiaries.read can see the base beneficiary record'
);

select is(
  (select count(*)::int from public.beneficiary_sensitive where beneficiary_id = 'g1111111-1111-1111-1111-111111111111'),
  0,
  'secretary WITHOUT beneficiaries.read.sensitive cannot see the sensitive companion row'
);

select throws_ok(
  $$ insert into public.partners (organization_name) values ('Blocked Partner') $$,
  'new row violates row-level security policy for table "partners"',
  'secretary cannot create a partner (has partners.read only, not partners.manage)'
);

-- ── Président: has beneficiaries.read.sensitive + partners.manage ──────────
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"f1111111-1111-1111-1111-111111111111"}';

select is(
  (select count(*)::int from public.beneficiary_sensitive where beneficiary_id = 'g1111111-1111-1111-1111-111111111111'),
  1,
  'president with beneficiaries.read.sensitive can see the sensitive companion row'
);

select lives_ok(
  $$ insert into public.partners (organization_name) values ('President-created Partner') $$,
  'president role CAN create a partner (has partners.manage)'
);

select throws_ok(
  $$ insert into public.beneficiary_categories (code, label_ar, label_fr, label_en)
     values ('other', 'أخرى', 'Autre', 'Other') $$,
  'new row violates row-level security policy for table "beneficiary_categories"',
  'president cannot create a beneficiary category (Admin-only per settings.manage, Section 12)'
);

select * from finish();
rollback;
