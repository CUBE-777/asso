-- 0025_financial_year.sql
-- Phase 7: Financial Years (Architecture Doc Section 18).

create table public.financial_year (
  id uuid primary key default gen_random_uuid(),
  year_label text not null unique,     -- e.g. '2026'
  start_date date not null,
  end_date date not null,
  status text not null default 'open' check (status in ('open','closed')),
  closed_at timestamptz,
  closed_by uuid references public.users_profile(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  check (end_date > start_date)
);

create trigger trg_financial_year_updated_at
  before update on public.financial_year
  for each row execute function public.set_updated_at();

create trigger trg_audit_financial_year
  after insert or update on public.financial_year
  for each row execute function public.audit_row_change();

-- Generic closed-year guard, reused by every finance table that carries a
-- financial_year_id column (Section 18: "once closed, normal modifications
-- should be restricted; sensitive changes require authorization; all changes
-- must be audited"). Reads the column dynamically via to_jsonb(NEW) so one
-- function covers transactions, donations, grants, etc. without duplicating
-- the logic per table.
create or replace function public.enforce_financial_year_not_closed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_fy_id uuid;
  v_status text;
begin
  v_fy_id := (to_jsonb(new)->>'financial_year_id')::uuid;
  if v_fy_id is null then
    return new;
  end if;

  select status into v_status from public.financial_year where id = v_fy_id;

  if v_status = 'closed' then
    if not auth_ext.has_permission('finance.override_closed_year') then
      raise exception 'financial year % is closed; finance.override_closed_year is required to modify it', v_fy_id;
    end if;
    insert into public.audit_log (actor_id, action, entity_type, entity_id, new_value, result)
    values (
      auth_ext.current_profile_id(), TG_TABLE_NAME || '.closed_year_override',
      TG_TABLE_NAME, (to_jsonb(new)->>'id')::uuid, to_jsonb(new), 'success'
    );
  end if;

  return new;
end;
$$;
