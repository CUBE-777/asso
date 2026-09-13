-- 0020_tasks.sql
-- Phase 5: Tasks (Architecture Doc Section 14).
-- A task has exactly one primary parent (project XOR activity XOR meeting
-- decision) or none — CHECK constraint per Architecture Doc Section 4's design
-- note, not a polymorphic link table (tasks are queried by their one parent
-- often enough that this is worth the slightly less generic model).

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  responsible_member_id uuid references public.members(id),
  start_date date,
  due_date date,
  priority text not null default 'medium' check (priority in ('low','medium','high','urgent')),
  status text not null default 'todo'
    check (status in ('todo','in_progress','blocked','completed','cancelled')),
  project_id uuid references public.projects(id),
  activity_id uuid references public.activities(id),
  meeting_decision_id uuid references public.meeting_decisions(id),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.users_profile(id),
  updated_by uuid references public.users_profile(id),
  deleted_at timestamptz,
  deleted_by uuid references public.users_profile(id),

  check (num_nonnulls(project_id, activity_id, meeting_decision_id) <= 1)
);

create index idx_tasks_responsible on public.tasks(responsible_member_id) where deleted_at is null;
create index idx_tasks_status on public.tasks(status) where deleted_at is null;
create index idx_tasks_project on public.tasks(project_id) where project_id is not null;
create index idx_tasks_activity on public.tasks(activity_id) where activity_id is not null;
create index idx_tasks_due_date on public.tasks(due_date) where deleted_at is null;

create trigger trg_tasks_updated_at
  before update on public.tasks
  for each row execute function public.set_updated_at();

create trigger trg_audit_tasks
  after insert or update or delete on public.tasks
  for each row execute function public.audit_row_change();

-- Status history (same auto-log pattern as member_status_history).
create table public.task_history (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks(id),
  previous_status text,
  new_status text not null,
  changed_at timestamptz not null default now(),
  changed_by uuid references public.users_profile(id)
);

create index idx_task_history_task on public.task_history(task_id, changed_at desc);

create or replace function public.log_task_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if TG_OP = 'INSERT' then
    insert into public.task_history (task_id, previous_status, new_status, changed_by)
    values (new.id, null, new.status, auth_ext.current_profile_id());
  elsif TG_OP = 'UPDATE' and new.status is distinct from old.status then
    insert into public.task_history (task_id, previous_status, new_status, changed_by)
    values (new.id, old.status, new.status, auth_ext.current_profile_id());
  end if;
  return new;
end;
$$;

create trigger trg_log_task_status_change
  after insert or update on public.tasks
  for each row execute function public.log_task_status_change();

-- Defense-in-depth: RLS (0021) lets a `tasks.update_own` holder UPDATE their
-- own assigned task, but the permission is meant for status/notes changes
-- only — not reassigning, retitling, or re-parenting the task. RLS alone
-- cannot restrict which COLUMNS change, so this trigger enforces it as a
-- second layer, matching Section 37 ("never trust a single enforcement
-- point for security-relevant behavior").
create or replace function public.enforce_task_update_own_scope()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth_ext.has_permission('tasks.manage') then
    return new;  -- full managers can change anything
  end if;

  if new.title is distinct from old.title
     or new.description is distinct from old.description
     or new.responsible_member_id is distinct from old.responsible_member_id
     or new.priority is distinct from old.priority
     or new.due_date is distinct from old.due_date
     or new.project_id is distinct from old.project_id
     or new.activity_id is distinct from old.activity_id
     or new.meeting_decision_id is distinct from old.meeting_decision_id
  then
    raise exception 'tasks.update_own may only change status and notes, not task ownership or scheduling fields';
  end if;

  return new;
end;
$$;

create trigger trg_enforce_task_update_own_scope
  before update on public.tasks
  for each row execute function public.enforce_task_update_own_scope();
