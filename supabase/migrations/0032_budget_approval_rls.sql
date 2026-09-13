-- 0032_budget_approval_rls.sql
-- Phase 8: RLS for budget + approval workflow.

alter table public.budget_categories enable row level security;
create policy budget_categories_select on public.budget_categories
  for select using (auth_ext.has_permission('finance.read') or auth_ext.has_permission('budget.read'));
create policy budget_categories_write on public.budget_categories for all
  using (auth_ext.has_permission('settings.manage')) with check (auth_ext.has_permission('settings.manage'));

alter table public.budgets enable row level security;
create policy budgets_select on public.budgets for select using (auth_ext.has_permission('budget.read'));
create policy budgets_write on public.budgets for all
  using (auth_ext.has_permission('budget.manage')) with check (auth_ext.has_permission('budget.manage'));

alter table public.budget_lines enable row level security;
create policy budget_lines_select on public.budget_lines for select using (auth_ext.has_permission('budget.read'));
create policy budget_lines_write on public.budget_lines for all
  using (auth_ext.has_permission('budget.manage')) with check (auth_ext.has_permission('budget.manage'));

alter table public.budget_reallocations enable row level security;
create policy budget_reallocations_select on public.budget_reallocations
  for select using (auth_ext.has_permission('budget.read'));
create policy budget_reallocations_insert on public.budget_reallocations
  for insert with check (auth_ext.has_permission('budget.manage'));

grant select on public.v_budget_line_status to authenticated;

-- ── approval_rules: Admin-configurable thresholds (Section 22) ──────────────
alter table public.approval_rules enable row level security;
create policy approval_rules_select on public.approval_rules
  for select using (auth_ext.has_permission('finance.read') or auth_ext.has_permission('budget.read'));
create policy approval_rules_write on public.approval_rules for all
  using (auth_ext.has_permission('settings.manage')) with check (auth_ext.has_permission('settings.manage'));

-- ── approval_requests: no insert/update policy — written only by the
-- SECURITY DEFINER triggers in 0031, never directly by a client ──────────────
alter table public.approval_requests enable row level security;
create policy approval_requests_select on public.approval_requests
  for select using (
    auth_ext.has_permission('finance.approve')
    or auth_ext.has_permission('budget.manage')
    or requested_by = auth_ext.current_profile_id()
  );

-- ── approval_decisions: the approval-level gate lives HERE, in the INSERT
-- check, not just in a generic "finance.approve" permission — a level-2
-- request additionally requires the Président or Admin role.
alter table public.approval_decisions enable row level security;
create policy approval_decisions_select on public.approval_decisions
  for select using (
    auth_ext.has_permission('finance.approve')
    or auth_ext.has_permission('budget.manage')
    or decided_by = auth_ext.current_profile_id()
  );

create policy approval_decisions_insert on public.approval_decisions
  for insert
  with check (
    exists (
      select 1 from public.approval_requests ar
      where ar.id = approval_decisions.approval_request_id
        and ar.status = 'pending'
        and (
          (ar.approval_level_required = 1 and auth_ext.has_permission('finance.approve'))
          or (
            ar.approval_level_required = 2
            and auth_ext.has_permission('finance.approve')
            and (auth_ext.has_role('president') or auth_ext.has_role('admin'))
          )
        )
    )
  );
