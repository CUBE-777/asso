-- 0015_partners.sql
-- Phase 4: Partners (Architecture Doc Section 11).

create table public.partners (
  id uuid primary key default gen_random_uuid(),
  organization_name text not null,
  partnership_type text,
  contact_person text,
  phone text,
  email citext,
  address text,
  start_date date,
  end_date date,
  notes text,

  search_vector tsvector generated always as (
    to_tsvector('simple', coalesce(organization_name,'') || ' ' || coalesce(contact_person,''))
  ) stored,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.users_profile(id),
  updated_by uuid references public.users_profile(id),
  deleted_at timestamptz,
  deleted_by uuid references public.users_profile(id)
);

create index idx_partners_search on public.partners using gin(search_vector);

create trigger trg_partners_updated_at
  before update on public.partners
  for each row execute function public.set_updated_at();

create trigger trg_audit_partners
  after insert or update or delete on public.partners
  for each row execute function public.audit_row_change();

create table public.partner_agreements (
  id uuid primary key default gen_random_uuid(),
  partner_id uuid not null references public.partners(id) on delete cascade,
  title text not null,
  description text,
  agreement_date date,
  start_date date,
  end_date date,
  status text not null default 'active' check (status in ('draft','active','expired','terminated')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.users_profile(id),
  updated_by uuid references public.users_profile(id)
);

create index idx_partner_agreements_partner on public.partner_agreements(partner_id);

create trigger trg_partner_agreements_updated_at
  before update on public.partner_agreements
  for each row execute function public.set_updated_at();
