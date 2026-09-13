-- 0027_membership_fees.sql
-- Phase 7: Membership fees (Architecture Doc Section 20).
-- Outstanding amount is NOT stored (would drift from payment history) — it's
-- a view, consistent with the "computed figures as views" principle applied
-- to budgets in Phase 8.

create table public.membership_fees (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.members(id),
  financial_year_id uuid not null references public.financial_year(id),
  amount_due numeric(14,2) not null check (amount_due >= 0),
  due_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.users_profile(id),
  updated_by uuid references public.users_profile(id),
  unique (member_id, financial_year_id)
);

create index idx_membership_fees_member on public.membership_fees(member_id);
create index idx_membership_fees_fy on public.membership_fees(financial_year_id);

create trigger trg_membership_fees_updated_at
  before update on public.membership_fees
  for each row execute function public.set_updated_at();

create trigger trg_membership_fees_closed_year_guard
  before insert or update on public.membership_fees
  for each row execute function public.enforce_financial_year_not_closed();

create table public.membership_fee_payments (
  id uuid primary key default gen_random_uuid(),
  membership_fee_id uuid not null references public.membership_fees(id),
  amount numeric(14,2) not null check (amount > 0),
  payment_date date not null default current_date,
  payment_method_id uuid not null references public.payment_methods(id),
  receipt_id uuid references public.receipts(id),
  recorded_by uuid references public.users_profile(id),
  created_at timestamptz not null default now()
);

create index idx_membership_fee_payments_fee on public.membership_fee_payments(membership_fee_id);

-- A late payment against a fee assessed in a now-closed year still needs the
-- override check — resolved via the parent membership_fees row's financial
-- year rather than duplicating financial_year_id onto this table.
create or replace function public.enforce_fy_not_closed_via_membership_fee()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
begin
  select fy.status into v_status
  from public.membership_fees mf
  join public.financial_year fy on fy.id = mf.financial_year_id
  where mf.id = new.membership_fee_id;

  if v_status = 'closed' and not auth_ext.has_permission('finance.override_closed_year') then
    raise exception 'the financial year for this membership fee is closed; finance.override_closed_year is required';
  end if;

  return new;
end;
$$;

create trigger trg_membership_fee_payments_closed_year_guard
  before insert on public.membership_fee_payments
  for each row execute function public.enforce_fy_not_closed_via_membership_fee();

-- Convenience view: outstanding balance per fee, computed, never stored.
create view public.v_membership_fee_status
with (security_invoker = on) as
select
  mf.id as membership_fee_id,
  mf.member_id,
  mf.financial_year_id,
  mf.amount_due,
  coalesce(sum(p.amount), 0)::numeric(14,2) as amount_paid,
  (mf.amount_due - coalesce(sum(p.amount), 0))::numeric(14,2) as outstanding_amount,
  case
    when coalesce(sum(p.amount), 0) >= mf.amount_due then 'paid'
    when coalesce(sum(p.amount), 0) > 0 then 'partially_paid'
    else 'unpaid'
  end as payment_status
from public.membership_fees mf
left join public.membership_fee_payments p on p.membership_fee_id = mf.id
group by mf.id, mf.member_id, mf.financial_year_id, mf.amount_due;
