-- 0031_approval_workflow.sql
-- Phase 8: Approval workflow (Architecture Doc Section 22).
-- Thresholds are DATA (approval_rules), never hard-coded amounts in application
-- code — Admin can change them later without a deployment.

create table public.approval_rules (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null check (entity_type in ('expense','budget_reallocation','project_approval')),
  min_amount numeric(14,2) not null default 0,
  max_amount numeric(14,2),          -- null = no upper bound
  approval_level int not null check (approval_level in (0,1,2)),
  -- 0 = no approval needed, 1 = standard approval (any finance.approve holder),
  -- 2 = strong approval (finance.approve AND president/admin role)
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  check (max_amount is null or max_amount > min_amount)
);

create trigger trg_approval_rules_updated_at
  before update on public.approval_rules
  for each row execute function public.set_updated_at();

create trigger trg_audit_approval_rules
  after insert or update or delete on public.approval_rules
  for each row execute function public.audit_row_change();

-- Seed the example thresholds from Section 22 as data, not code — Admin can
-- change these amounts later via settings.manage, no migration required.
insert into public.approval_rules (entity_type, min_amount, max_amount, approval_level, description) values
  ('expense', 0,        5000,  0, 'Below 5,000 MAD: normal permission, no approval required'),
  ('expense', 5000.01,  20000, 1, 'Between 5,000 and 20,000 MAD: standard approval required'),
  ('expense', 20000.01, null,  2, 'Above 20,000 MAD: strong approval required (Président/Admin)');

create or replace function public.get_required_approval_level(p_entity_type text, p_amount numeric)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select approval_level from public.approval_rules
     where entity_type = p_entity_type and is_active
       and p_amount >= min_amount and (max_amount is null or p_amount <= max_amount)
     order by approval_level desc limit 1),
    0
  );
$$;

create table public.approval_requests (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null check (entity_type in ('expense','budget_reallocation','project_approval')),
  entity_id uuid not null,
  approval_level_required int not null check (approval_level_required in (1,2)),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  requested_by uuid references public.users_profile(id),
  requested_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid references public.users_profile(id),
  notes text
);

create index idx_approval_requests_entity on public.approval_requests(entity_type, entity_id);
create index idx_approval_requests_status on public.approval_requests(status);

create trigger trg_audit_approval_requests
  after insert or update on public.approval_requests
  for each row execute function public.audit_row_change();

create table public.approval_decisions (
  id uuid primary key default gen_random_uuid(),
  approval_request_id uuid not null references public.approval_requests(id),
  decided_by uuid not null references public.users_profile(id),
  decision text not null check (decision in ('approved','rejected')),
  decided_at timestamptz not null default now(),
  comment text
);

create trigger trg_audit_approval_decisions
  after insert on public.approval_decisions
  for each row execute function public.audit_row_change();

-- ── The actual enforcement: no client write can bypass this (Architecture Doc
-- Section 15.5 risk) because it runs regardless of what `status` the client
-- sent on INSERT.
create or replace function public.enforce_expense_approval_threshold()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_level int;
begin
  if new.transaction_type = 'expense' then
    v_level := public.get_required_approval_level('expense', new.amount);
    if v_level > 0 then
      new.status := 'pending_approval';
    else
      new.status := 'completed';
    end if;
  end if;
  return new;
end;
$$;

create trigger trg_enforce_expense_approval_threshold
  before insert on public.transactions
  for each row execute function public.enforce_expense_approval_threshold();

-- Once the row exists (id is available — defaults apply before BEFORE
-- triggers run), create the approval_requests row if it needs one.
create or replace function public.create_approval_request_for_transaction()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_level int;
begin
  if new.transaction_type = 'expense' and new.status = 'pending_approval' then
    v_level := public.get_required_approval_level('expense', new.amount);
    insert into public.approval_requests (entity_type, entity_id, approval_level_required, requested_by)
    values ('expense', new.id, v_level, new.created_by);
  end if;
  return new;
end;
$$;

create trigger trg_create_approval_request_for_transaction
  after insert on public.transactions
  for each row execute function public.create_approval_request_for_transaction();

-- When a decision is recorded, resolve the request and propagate the outcome
-- back onto the transaction — this is the only path a transaction can leave
-- 'pending_approval' (no direct client UPDATE of transactions.status is
-- allowed to do this; see 0032 RLS).
create or replace function public.resolve_approval_from_decision()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request public.approval_requests%rowtype;
begin
  select * into v_request from public.approval_requests where id = new.approval_request_id;

  update public.approval_requests
  set status = new.decision, resolved_at = now(), resolved_by = new.decided_by
  where id = new.approval_request_id;

  if v_request.entity_type = 'expense' then
    -- Flip a transaction-local flag so the guard trigger below (which blocks
    -- direct client edits to a pending transaction's status) lets this
    -- specific, system-driven update through.
    perform set_config('ams.bypass_status_guard', 'true', true);
    update public.transactions
    set status = case when new.decision = 'approved' then 'approved' else 'rejected' end
    where id = v_request.entity_id;
    perform set_config('ams.bypass_status_guard', 'false', true);
  end if;

  return new;
end;
$$;

create trigger trg_resolve_approval_from_decision
  after insert on public.approval_decisions
  for each row execute function public.resolve_approval_from_decision();

-- Guard: once a transaction is 'pending_approval', its status can only move
-- forward through the approval_decisions flow above — never a direct client
-- UPDATE, even from someone holding finance.create/finance.approve on the
-- base transactions_update RLS policy (Section 15 risk 5: "approval workflow
-- bypass via direct table writes").
create or replace function public.guard_transaction_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status is distinct from old.status then
    if coalesce(current_setting('ams.bypass_status_guard', true), 'false') = 'true' then
      return new;
    end if;
    if old.status = 'pending_approval' then
      raise exception 'a pending_approval transaction''s status can only change via an approval_decisions record, not a direct update';
    end if;
  end if;
  return new;
end;
$$;

create trigger trg_guard_transaction_status_change
  before update on public.transactions
  for each row execute function public.guard_transaction_status_change();
