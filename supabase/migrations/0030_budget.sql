-- 0030_budget.sql
-- Phase 8: Budgeting (Architecture Doc Section 19).
-- Prévision (planned_amount, stored) vs Réel (actual, computed from
-- transactions) vs Écart (variance, computed) — actual/remaining/variance/
-- consumption are a VIEW, never stored columns, per the architecture doc's
-- Section 18.3 recommendation (avoids drift from the underlying transactions).

create table public.budget_categories (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  label_ar text not null,
  label_fr text not null,
  label_en text not null,
  created_at timestamptz not null default now()
);

create table public.budgets (
  id uuid primary key default gen_random_uuid(),
  financial_year_id uuid not null references public.financial_year(id),
  name text not null,
  status text not null default 'draft' check (status in ('draft','approved','closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.users_profile(id),
  updated_by uuid references public.users_profile(id),
  unique (financial_year_id, name)
);

create trigger trg_budgets_updated_at
  before update on public.budgets
  for each row execute function public.set_updated_at();

create trigger trg_audit_budgets
  after insert or update or delete on public.budgets
  for each row execute function public.audit_row_change();

create table public.budget_lines (
  id uuid primary key default gen_random_uuid(),
  budget_id uuid not null references public.budgets(id) on delete cascade,
  category_id uuid references public.budget_categories(id),
  project_id uuid references public.projects(id),
  activity_id uuid references public.activities(id),
  planned_amount numeric(14,2) not null check (planned_amount >= 0),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.users_profile(id),
  updated_by uuid references public.users_profile(id),

  check (num_nonnulls(project_id, activity_id) <= 1)
);

create index idx_budget_lines_budget on public.budget_lines(budget_id);
create index idx_budget_lines_project on public.budget_lines(project_id) where project_id is not null;
create index idx_budget_lines_activity on public.budget_lines(activity_id) where activity_id is not null;

create trigger trg_budget_lines_updated_at
  before update on public.budget_lines
  for each row execute function public.set_updated_at();

create trigger trg_audit_budget_lines
  after insert or update or delete on public.budget_lines
  for each row execute function public.audit_row_change();

create table public.budget_reallocations (
  id uuid primary key default gen_random_uuid(),
  budget_id uuid not null references public.budgets(id),
  from_line_id uuid not null references public.budget_lines(id),
  to_line_id uuid not null references public.budget_lines(id),
  amount numeric(14,2) not null check (amount > 0),
  reason text not null,
  created_at timestamptz not null default now(),
  created_by uuid references public.users_profile(id),

  check (from_line_id <> to_line_id)
);

create trigger trg_audit_budget_reallocations
  after insert on public.budget_reallocations
  for each row execute function public.audit_row_change();

-- Applying a reallocation actually moves money between lines' planned_amount
-- (the reallocation row itself is the permanent log of that it happened).
create or replace function public.apply_budget_reallocation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.budget_lines set planned_amount = planned_amount - new.amount where id = new.from_line_id;
  update public.budget_lines set planned_amount = planned_amount + new.amount where id = new.to_line_id;
  return new;
end;
$$;

create trigger trg_apply_budget_reallocation
  after insert on public.budget_reallocations
  for each row execute function public.apply_budget_reallocation();

-- Prévision / Réel / Écart / consumption, computed live from transactions —
-- never stored (Section 19 + 18.3).
create view public.v_budget_line_status
with (security_invoker = on) as
select
  bl.id as budget_line_id,
  bl.budget_id,
  b.financial_year_id,
  bl.category_id,
  bl.project_id,
  bl.activity_id,
  bl.planned_amount,
  coalesce((
    select sum(t.amount) from public.transactions t
    where t.deleted_at is null
      and t.transaction_type = 'expense'
      and t.financial_year_id = b.financial_year_id
      and t.status in ('approved','completed')
      and (
        (bl.project_id is not null and t.project_id = bl.project_id)
        or (bl.activity_id is not null and t.activity_id = bl.activity_id)
        or (bl.project_id is null and bl.activity_id is null
            and t.category_id = bl.category_id and t.project_id is null and t.activity_id is null)
      )
  ), 0)::numeric(14,2) as actual_amount,
  (bl.planned_amount - coalesce((
    select sum(t.amount) from public.transactions t
    where t.deleted_at is null
      and t.transaction_type = 'expense'
      and t.financial_year_id = b.financial_year_id
      and t.status in ('approved','completed')
      and (
        (bl.project_id is not null and t.project_id = bl.project_id)
        or (bl.activity_id is not null and t.activity_id = bl.activity_id)
        or (bl.project_id is null and bl.activity_id is null
            and t.category_id = bl.category_id and t.project_id is null and t.activity_id is null)
      )
  ), 0))::numeric(14,2) as remaining_amount
from public.budget_lines bl
join public.budgets b on b.id = bl.budget_id;
