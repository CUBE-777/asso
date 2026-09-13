-- 0006_phase8_approval_workflow.sql
-- pgTAP tests for approval-threshold enforcement (Architecture Doc Section 22 / 15.5).
begin;
select plan(8);

-- ── Fixtures ──────────────────────────────────────────────────────────────────
insert into auth.users (id, email) values
  ('k1111111-1111-1111-1111-111111111111', 'treasurer8@test.local'),
  ('k2222222-2222-2222-2222-222222222222', 'president8@test.local');

insert into public.user_roles (user_id, role_id)
select 'k1111111-1111-1111-1111-111111111111', id from public.roles where code = 'treasurer'
on conflict do nothing;
insert into public.user_roles (user_id, role_id)
select 'k2222222-2222-2222-2222-222222222222', id from public.roles where code = 'president'
on conflict do nothing;

insert into public.financial_year (id, year_label, start_date, end_date, status) values
  ('l1111111-1111-1111-1111-111111111111', 'FY-TEST-8', '2026-01-01', '2026-12-31', 'open');
insert into public.accounts (id, name) values ('m1111111-1111-1111-1111-111111111111', 'Test Cash Account');
insert into public.transaction_categories (id, code, label_ar, label_fr, label_en, category_type)
  values ('n1111111-1111-1111-1111-111111111111', 'test-expense', 'مصروف', 'Dépense', 'Expense', 'expense');

-- ── Act as Trésorier (finance.create + finance.approve, level-1 only) ───────
set local role authenticated;
set local request.jwt.claims = '{"sub":"k1111111-1111-1111-1111-111111111111"}';

-- Small expense: auto-completed, no approval needed.
insert into public.transactions (id, financial_year_id, account_id, category_id, payment_method_id, transaction_type, amount, status)
select 'o1111111-1111-1111-1111-111111111111', 'l1111111-1111-1111-1111-111111111111',
       'm1111111-1111-1111-1111-111111111111', 'n1111111-1111-1111-1111-111111111111',
       pm.id, 'expense', 1000, 'pending_approval'  -- deliberately lying about status to prove the trigger overrides it
from public.payment_methods pm where pm.code = 'cash';

select is(
  (select status from public.transactions where id = 'o1111111-1111-1111-1111-111111111111'),
  'completed',
  'a small expense is forced to completed regardless of what status the client sent'
);

select is(
  (select count(*)::int from public.approval_requests where entity_id = 'o1111111-1111-1111-1111-111111111111'),
  0,
  'no approval_requests row is created for a below-threshold expense'
);

-- Mid-size expense: requires level-1 approval.
insert into public.transactions (id, financial_year_id, account_id, category_id, payment_method_id, transaction_type, amount)
select 'o2222222-2222-2222-2222-222222222222', 'l1111111-1111-1111-1111-111111111111',
       'm1111111-1111-1111-1111-111111111111', 'n1111111-1111-1111-1111-111111111111',
       pm.id, 'expense', 10000
from public.payment_methods pm where pm.code = 'cash';

select is(
  (select status from public.transactions where id = 'o2222222-2222-2222-2222-222222222222'),
  'pending_approval',
  'a mid-size expense (5,000-20,000 MAD) is forced to pending_approval'
);

select throws_ok(
  $$ update public.transactions set status = 'approved' where id = 'o2222222-2222-2222-2222-222222222222' $$,
  'a pending_approval transaction''s status can only change via an approval_decisions record, not a direct update',
  'a direct UPDATE cannot bypass the approval workflow, even by a finance.approve holder'
);

-- Treasurer (level-1 sufficient) approves via the proper channel.
select lives_ok(
  $$ insert into public.approval_decisions (approval_request_id, decided_by, decision)
     select id, 'k1111111-1111-1111-1111-111111111111', 'approved'
     from public.approval_requests where entity_id = 'o2222222-2222-2222-2222-222222222222' $$,
  'treasurer (finance.approve) can resolve a level-1 approval request'
);

select is(
  (select status from public.transactions where id = 'o2222222-2222-2222-2222-222222222222'),
  'approved',
  'the transaction status flips to approved once the decision is recorded'
);

-- Large expense: requires level-2 (Président/Admin), treasurer alone is not enough.
insert into public.transactions (id, financial_year_id, account_id, category_id, payment_method_id, transaction_type, amount)
select 'o3333333-3333-3333-3333-333333333333', 'l1111111-1111-1111-1111-111111111111',
       'm1111111-1111-1111-1111-111111111111', 'n1111111-1111-1111-1111-111111111111',
       pm.id, 'expense', 50000
from public.payment_methods pm where pm.code = 'cash';

select throws_ok(
  $$ insert into public.approval_decisions (approval_request_id, decided_by, decision)
     select id, 'k1111111-1111-1111-1111-111111111111', 'approved'
     from public.approval_requests where entity_id = 'o3333333-3333-3333-3333-333333333333' $$,
  'new row violates row-level security policy for table "approval_decisions"',
  'treasurer alone cannot resolve a level-2 (strong) approval request'
);

-- ── Switch to Président: can resolve level-2 ─────────────────────────────────
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"k2222222-2222-2222-2222-222222222222"}';

select lives_ok(
  $$ insert into public.approval_decisions (approval_request_id, decided_by, decision)
     select id, 'k2222222-2222-2222-2222-222222222222', 'approved'
     from public.approval_requests where entity_id = 'o3333333-3333-3333-3333-333333333333' $$,
  'president CAN resolve a level-2 (strong) approval request'
);

select * from finish();
rollback;
