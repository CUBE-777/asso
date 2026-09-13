-- 0033_reports_dashboard.sql
-- Phase 9: Reports + Dashboard (Architecture Doc Section 28-29) — the
-- database-layer half only. PDF/Excel export and the actual dashboard UI are
-- frontend + Edge Function work that needs a real deployed project to build
-- and test against meaningfully (see the project README's "what remains").
--
-- Président holds finance.read.summary but NOT finance.read (Section 6), so a
-- plain view over `transactions` would return zero rows for them (RLS on the
-- base table still applies even through a security_invoker view). A
-- SECURITY DEFINER function that returns ONLY aggregates — never row-level
-- detail — is how "summary but not line-item access" is actually enforced,
-- not just described in a permission matrix.

create or replace function public.get_financial_summary(p_financial_year_id uuid)
returns table (total_revenue numeric, total_expense numeric, balance numeric)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not (auth_ext.has_permission('finance.read') or auth_ext.has_permission('finance.read.summary')) then
    raise exception 'finance.read or finance.read.summary permission is required';
  end if;

  return query
  select
    coalesce(sum(amount) filter (where transaction_type = 'revenue'), 0)::numeric(14,2),
    coalesce(sum(amount) filter (where transaction_type = 'expense'), 0)::numeric(14,2),
    (coalesce(sum(amount) filter (where transaction_type = 'revenue'), 0)
     - coalesce(sum(amount) filter (where transaction_type = 'expense'), 0))::numeric(14,2)
  from public.transactions
  where financial_year_id = p_financial_year_id
    and deleted_at is null
    and status in ('approved','completed');
end;
$$;

create or replace function public.get_budget_consumption_summary(p_financial_year_id uuid)
returns table (total_planned numeric, total_actual numeric, consumption_rate numeric)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not (auth_ext.has_permission('budget.read') or auth_ext.has_permission('finance.read.summary')) then
    raise exception 'budget.read or finance.read.summary permission is required';
  end if;

  return query
  select
    coalesce(sum(planned_amount), 0)::numeric(14,2),
    coalesce(sum(actual_amount), 0)::numeric(14,2),
    case when coalesce(sum(planned_amount), 0) = 0 then 0
         else round(coalesce(sum(actual_amount), 0) / sum(planned_amount) * 100, 2)
    end
  from public.v_budget_line_status
  where financial_year_id = p_financial_year_id;
end;
$$;

-- Pending-approvals widget (Section 28: Admin dashboard "Pending approvals").
-- A plain view is fine here — approval_requests' own RLS (0032) already
-- scopes it to finance.approve/budget.manage holders or the requester.
create view public.v_pending_approvals
with (security_invoker = on) as
select
  ar.id as approval_request_id,
  ar.entity_type,
  ar.entity_id,
  ar.approval_level_required,
  ar.requested_at,
  ar.requested_by,
  t.amount as transaction_amount
from public.approval_requests ar
left join public.transactions t on ar.entity_type = 'expense' and t.id = ar.entity_id
where ar.status = 'pending';

grant select on public.v_pending_approvals to authenticated;
grant execute on function public.get_financial_summary(uuid) to authenticated;
grant execute on function public.get_budget_consumption_summary(uuid) to authenticated;
