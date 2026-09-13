-- 0029_finance_rls.sql
-- Phase 7: RLS for finance tables.
-- Note: finance.read.summary holders (e.g. Président) deliberately do NOT get
-- row-level access to raw `transactions` here — they see aggregates through a
-- view introduced in Phase 9 (Reports/Dashboard), matching the permission
-- matrix's "summary only" intent for that role.

alter table public.financial_year enable row level security;
create policy financial_year_select on public.financial_year for select using (auth_ext.has_permission('finance.read'));
create policy financial_year_write on public.financial_year for all
  using (auth_ext.has_permission('finance.approve')) with check (auth_ext.has_permission('finance.approve'));

alter table public.accounts enable row level security;
create policy accounts_select on public.accounts for select using (auth_ext.has_permission('finance.read'));
create policy accounts_write on public.accounts for all
  using (auth_ext.has_permission('settings.manage')) with check (auth_ext.has_permission('settings.manage'));

alter table public.payment_methods enable row level security;
create policy payment_methods_select on public.payment_methods for select using (auth_ext.has_permission('finance.read'));
create policy payment_methods_write on public.payment_methods for all
  using (auth_ext.has_permission('settings.manage')) with check (auth_ext.has_permission('settings.manage'));

alter table public.transaction_categories enable row level security;
create policy transaction_categories_select on public.transaction_categories for select using (auth_ext.has_permission('finance.read'));
create policy transaction_categories_write on public.transaction_categories for all
  using (auth_ext.has_permission('settings.manage')) with check (auth_ext.has_permission('settings.manage'));

alter table public.transactions enable row level security;
create policy transactions_select on public.transactions
  for select using (deleted_at is null and auth_ext.has_permission('finance.read'));
create policy transactions_insert on public.transactions
  for insert with check (auth_ext.has_permission('finance.create'));
create policy transactions_update on public.transactions
  for update
  using (auth_ext.has_permission('finance.create') or auth_ext.has_permission('finance.approve'))
  with check (auth_ext.has_permission('finance.create') or auth_ext.has_permission('finance.approve'));

alter table public.receipts enable row level security;
create policy receipts_select on public.receipts for select using (auth_ext.has_permission('finance.read'));
create policy receipts_insert on public.receipts for insert with check (auth_ext.has_permission('finance.create'));

alter table public.invoices enable row level security;
create policy invoices_select on public.invoices for select using (auth_ext.has_permission('finance.read'));
create policy invoices_write on public.invoices for all
  using (auth_ext.has_permission('finance.create') or auth_ext.has_permission('finance.approve'))
  with check (auth_ext.has_permission('finance.create') or auth_ext.has_permission('finance.approve'));

-- ── membership fees: a member can see (not edit) their own fee/payment history ──
alter table public.membership_fees enable row level security;
create policy membership_fees_select on public.membership_fees
  for select using (auth_ext.has_permission('finance.read') or member_id = auth_ext.current_member_id());
create policy membership_fees_write on public.membership_fees
  for all using (auth_ext.has_permission('finance.create')) with check (auth_ext.has_permission('finance.create'));

alter table public.membership_fee_payments enable row level security;
create policy membership_fee_payments_select on public.membership_fee_payments
  for select using (
    auth_ext.has_permission('finance.read')
    or exists (
      select 1 from public.membership_fees mf
      where mf.id = membership_fee_payments.membership_fee_id and mf.member_id = auth_ext.current_member_id()
    )
  );
create policy membership_fee_payments_insert on public.membership_fee_payments
  for insert with check (auth_ext.has_permission('finance.create'));

grant select on public.v_membership_fee_status to authenticated;

alter table public.donations enable row level security;
create policy donations_select on public.donations for select using (auth_ext.has_permission('finance.read'));
create policy donations_write on public.donations for all
  using (auth_ext.has_permission('finance.create')) with check (auth_ext.has_permission('finance.create'));

alter table public.grants enable row level security;
create policy grants_select on public.grants for select using (auth_ext.has_permission('finance.read'));
create policy grants_write on public.grants for all
  using (auth_ext.has_permission('finance.create')) with check (auth_ext.has_permission('finance.create'));
