-- 0006_settings.sql
-- Phase 1: Association & System settings (Architecture Doc Section 26).
-- Both are singleton tables enforced via a check constraint on a fixed id,
-- so "no developer needed to change basic association info" (Section 26)
-- while still keeping full audit/versioning behavior of a normal table.

create table public.association_settings (
  id boolean primary key default true,
  check (id),  -- singleton enforcement: only one row can ever exist
  name text not null default 'الجمعية',
  logo_path text,
  description text,
  address text,
  phone text,
  email citext,
  website text,
  social_networks jsonb not null default '{}'::jsonb,
  legal_info jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.users_profile(id)
);

create table public.system_settings (
  id boolean primary key default true,
  check (id),
  default_language text not null default 'ar' check (default_language in ('ar','fr','en')),
  default_theme text not null default 'dark' check (default_theme in ('dark','light')),
  currency text not null default 'MAD',
  date_format text not null default 'DD/MM/YYYY',
  timezone text not null default 'Africa/Casablanca',
  fiscal_year_start_month int not null default 1 check (fiscal_year_start_month between 1 and 12),
  receipt_settings jsonb not null default '{}'::jsonb,
  report_settings jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.users_profile(id)
);

insert into public.association_settings (id) values (true) on conflict do nothing;
insert into public.system_settings (id) values (true) on conflict do nothing;

create trigger trg_association_settings_updated_at
  before update on public.association_settings
  for each row execute function public.set_updated_at();

create trigger trg_system_settings_updated_at
  before update on public.system_settings
  for each row execute function public.set_updated_at();

create trigger trg_audit_association_settings
  after update on public.association_settings
  for each row execute function public.audit_row_change();

create trigger trg_audit_system_settings
  after update on public.system_settings
  for each row execute function public.audit_row_change();
