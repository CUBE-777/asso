-- 0028_donations_grants.sql
-- Phase 7: Donations and Grants (Architecture Doc Section 21).
-- Architecture-ready per Section 21 ("may be implemented gradually") — the
-- schema is complete now even though the UI for these may land later.

create table public.donations (
  id uuid primary key default gen_random_uuid(),
  donor_name text not null,
  donor_type text check (donor_type in ('individual','organization')),
  amount numeric(14,2) not null check (amount > 0),
  donation_date date not null default current_date,
  source text,
  project_id uuid references public.projects(id),
  financial_year_id uuid not null references public.financial_year(id),
  notes text,
  created_at timestamptz not null default now(),
  created_by uuid references public.users_profile(id)
);

create index idx_donations_fy on public.donations(financial_year_id);
create index idx_donations_project on public.donations(project_id) where project_id is not null;

create trigger trg_audit_donations
  after insert or update or delete on public.donations
  for each row execute function public.audit_row_change();

create trigger trg_donations_closed_year_guard
  before insert or update on public.donations
  for each row execute function public.enforce_financial_year_not_closed();

create table public.grants (
  id uuid primary key default gen_random_uuid(),
  grantor_name text not null,
  amount numeric(14,2) not null check (amount > 0),
  grant_date date not null default current_date,
  financial_year_id uuid not null references public.financial_year(id),
  project_id uuid references public.projects(id),
  status text not null default 'pending' check (status in ('pending','received','completed','cancelled')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.users_profile(id),
  updated_by uuid references public.users_profile(id)
);

create index idx_grants_fy on public.grants(financial_year_id);
create index idx_grants_project on public.grants(project_id) where project_id is not null;

create trigger trg_grants_updated_at
  before update on public.grants
  for each row execute function public.set_updated_at();

create trigger trg_audit_grants
  after insert or update or delete on public.grants
  for each row execute function public.audit_row_change();

create trigger trg_grants_closed_year_guard
  before insert or update on public.grants
  for each row execute function public.enforce_financial_year_not_closed();

-- Corrective migration (per CONTRIBUTING.md: never edit a merged migration):
-- document_links.check_document_link_integrity (0022) predates the
-- transactions table and rejected entity_type='transaction' outright. Now
-- that transactions exists, replace the function to actually validate it.
create or replace function public.check_document_link_integrity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_exists boolean;
begin
  case new.entity_type
    when 'member'      then select exists(select 1 from public.members where id = new.entity_id) into v_exists;
    when 'project'      then select exists(select 1 from public.projects where id = new.entity_id) into v_exists;
    when 'activity'     then select exists(select 1 from public.activities where id = new.entity_id) into v_exists;
    when 'partner'      then select exists(select 1 from public.partners where id = new.entity_id) into v_exists;
    when 'beneficiary'  then select exists(select 1 from public.beneficiaries where id = new.entity_id) into v_exists;
    when 'meeting'      then select exists(select 1 from public.meetings where id = new.entity_id) into v_exists;
    when 'transaction'  then select exists(select 1 from public.transactions where id = new.entity_id) into v_exists;
    else v_exists := false;
  end case;

  if not v_exists then
    raise exception 'document_links.entity_id % does not exist in the % table', new.entity_id, new.entity_type;
  end if;

  return new;
end;
$$;
