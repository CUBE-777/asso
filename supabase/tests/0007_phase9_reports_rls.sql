-- 0007_phase9_reports_rls.sql
begin;
select plan(3);

insert into auth.users (id, email) values
  ('p1111111-1111-1111-1111-111111111111', 'president9@test.local'),
  ('p2222222-2222-2222-2222-222222222222', 'plainmember9@test.local');

insert into public.user_roles (user_id, role_id)
select 'p1111111-1111-1111-1111-111111111111', id from public.roles where code = 'president'
on conflict do nothing;
-- p2222222... keeps only the default 'member' role (no finance permissions at all).

insert into public.financial_year (id, year_label, start_date, end_date, status) values
  ('q1111111-1111-1111-1111-111111111111', 'FY-TEST-9', '2026-01-01', '2026-12-31', 'open');

set local role authenticated;
set local request.jwt.claims = '{"sub":"p1111111-1111-1111-1111-111111111111"}';

select lives_ok(
  $$ select * from public.get_financial_summary('q1111111-1111-1111-1111-111111111111') $$,
  'president (finance.read.summary) can call get_financial_summary'
);

select is(
  (select total_revenue from public.get_financial_summary('q1111111-1111-1111-1111-111111111111')),
  0::numeric,
  'an empty financial year summarizes to zero, not an error, for an authorized caller'
);

reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"p2222222-2222-2222-2222-222222222222"}';

select throws_ok(
  $$ select * from public.get_financial_summary('q1111111-1111-1111-1111-111111111111') $$,
  'finance.read or finance.read.summary permission is required',
  'a plain member with no finance permission cannot call get_financial_summary'
);

select * from finish();
rollback;
