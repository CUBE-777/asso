-- 0016_beneficiaries.sql
-- Phase 4: Beneficiaries (Architecture Doc Section 12).
--
-- Sensitive fields (contact info, private notes) live in a SEPARATE table
-- (`beneficiary_sensitive`) rather than as columns on `beneficiaries`, because
-- Postgres has no column-level RLS — this is how "sensitive beneficiary
-- information must be protected by permissions" (Section 12) is actually
-- enforceable at the database layer (Section 18.2 of the architecture doc).
--
-- Categories are admin-configurable data, never a hard-coded enum (Section 12:
-- "do not hard-code categories").

create table public.beneficiary_categories (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  label_ar text not null,
  label_fr text not null,
  label_en text not null,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.users_profile(id),
  updated_by uuid references public.users_profile(id)
);

create trigger trg_beneficiary_categories_updated_at
  before update on public.beneficiary_categories
  for each row execute function public.set_updated_at();

create table public.beneficiaries (
  id uuid primary key default gen_random_uuid(),
  category_id uuid references public.beneficiary_categories(id),
  display_name text not null,     -- non-sensitive label (can be a code/alias, not necessarily a legal name)
  general_notes text,             -- non-sensitive context only; private notes go in beneficiary_notes

  search_vector tsvector generated always as (
    to_tsvector('simple', coalesce(display_name,''))
  ) stored,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.users_profile(id),
  updated_by uuid references public.users_profile(id),
  deleted_at timestamptz,
  deleted_by uuid references public.users_profile(id)
);

create index idx_beneficiaries_category on public.beneficiaries(category_id) where deleted_at is null;
create index idx_beneficiaries_search on public.beneficiaries using gin(search_vector);

create trigger trg_beneficiaries_updated_at
  before update on public.beneficiaries
  for each row execute function public.set_updated_at();

create trigger trg_audit_beneficiaries
  after insert or update or delete on public.beneficiaries
  for each row execute function public.audit_row_change();

-- Sensitive companion table — one row per beneficiary, gated by a stricter
-- permission (beneficiaries.read.sensitive) than the base profile.
create table public.beneficiary_sensitive (
  beneficiary_id uuid primary key references public.beneficiaries(id) on delete cascade,
  full_name text,
  phone text,
  email citext,
  address text,
  national_id text,
  sensitive_notes text,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.users_profile(id)
);

create trigger trg_beneficiary_sensitive_updated_at
  before update on public.beneficiary_sensitive
  for each row execute function public.set_updated_at();

create trigger trg_audit_beneficiary_sensitive
  after insert or update or delete on public.beneficiary_sensitive
  for each row execute function public.audit_row_change();

-- Dated notes history (Section 3 lists beneficiary_notes as its own entity,
-- distinct from a single overwritable notes field — matches Section 12's
-- "Full history" requirement).
create table public.beneficiary_notes (
  id uuid primary key default gen_random_uuid(),
  beneficiary_id uuid not null references public.beneficiaries(id) on delete cascade,
  note text not null,
  created_at timestamptz not null default now(),
  created_by uuid references public.users_profile(id)
);

create index idx_beneficiary_notes_beneficiary on public.beneficiary_notes(beneficiary_id, created_at desc);
