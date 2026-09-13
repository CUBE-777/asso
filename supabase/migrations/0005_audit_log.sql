-- 0005_audit_log.sql
-- Phase 1: Audit Log (Architecture Doc Section 12).
-- Append-only. No application role ever receives UPDATE/DELETE grants on this table.

create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  occurred_at timestamptz not null default now(),
  actor_id uuid,                     -- nullable: system-triggered events
  action text not null,              -- e.g. 'member.status_changed', 'role.assigned'
  entity_type text,
  entity_id uuid,
  previous_value jsonb,
  new_value jsonb,
  ip_address inet,
  device_info text,
  result text not null default 'success' check (result in ('success','failure'))
);

create index idx_audit_entity on public.audit_log(entity_type, entity_id);
create index idx_audit_actor_time on public.audit_log(actor_id, occurred_at desc);
create index idx_audit_action on public.audit_log(action);

-- Generic trigger function: any future table can attach this trigger to get
-- automatic INSERT/UPDATE/DELETE auditing without bespoke code per table.
-- Sensitive/huge columns can be excluded per-table later by wrapping this in
-- a table-specific trigger if needed; Phase 1 tables are small enough not to need that.
create or replace function public.audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_action text;
  v_entity_id uuid;
begin
  v_action := TG_TABLE_NAME || '.' ||
    case TG_OP when 'INSERT' then 'created'
               when 'UPDATE' then 'updated'
               when 'DELETE' then 'deleted' end;

  v_entity_id := case TG_OP when 'DELETE' then OLD.id else NEW.id end;

  insert into public.audit_log (actor_id, action, entity_type, entity_id, previous_value, new_value)
  values (
    auth_ext.current_profile_id(),
    v_action,
    TG_TABLE_NAME,
    v_entity_id,
    case when TG_OP in ('UPDATE','DELETE') then to_jsonb(OLD) else null end,
    case when TG_OP in ('INSERT','UPDATE') then to_jsonb(NEW) else null end
  );

  return coalesce(NEW, OLD);
end;
$$;

-- Attach auditing to Phase 1 security-sensitive tables now (Section 31 explicitly
-- lists user/role/permission changes as must-audit events).
create trigger trg_audit_users_profile
  after insert or update or delete on public.users_profile
  for each row execute function public.audit_row_change();

create trigger trg_audit_user_roles
  after insert or update or delete on public.user_roles
  for each row execute function public.audit_row_change();

create trigger trg_audit_role_permissions
  after insert or update or delete on public.role_permissions
  for each row execute function public.audit_row_change();
