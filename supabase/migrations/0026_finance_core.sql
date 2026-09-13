-- 0026_finance_core.sql
-- Phase 7: Core finance tables (Architecture Doc Section 17).
-- All monetary columns are numeric(14,2) — never float/double precision.

create table public.accounts (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  account_type text not null default 'cash' check (account_type in ('cash','bank')),
  currency text not null default 'MAD',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- V1 ships with only 'cash' active; the table exists so bank/check/card can
-- be enabled later without a schema change (Section 17/20).
create table public.payment_methods (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code in ('cash','bank_transfer','check','card','other')),
  label_ar text not null,
  label_fr text not null,
  label_en text not null,
  is_active boolean not null default false
);

insert into public.payment_methods (code, label_ar, label_fr, label_en, is_active) values
  ('cash', 'نقدا', 'Espèces', 'Cash', true),
  ('bank_transfer', 'تحويل بنكي', 'Virement bancaire', 'Bank transfer', false),
  ('check', 'شيك', 'Chèque', 'Check', false),
  ('card', 'بطاقة', 'Carte', 'Card', false),
  ('other', 'أخرى', 'Autre', 'Other', false);

create table public.transaction_categories (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  label_ar text not null,
  label_fr text not null,
  label_en text not null,
  category_type text not null check (category_type in ('revenue','expense'))
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  financial_year_id uuid not null references public.financial_year(id),
  account_id uuid not null references public.accounts(id),
  category_id uuid not null references public.transaction_categories(id),
  payment_method_id uuid not null references public.payment_methods(id),
  transaction_type text not null check (transaction_type in ('revenue','expense')),
  amount numeric(14,2) not null check (amount > 0),
  transaction_date date not null default current_date,
  description text,
  project_id uuid references public.projects(id),
  activity_id uuid references public.activities(id),
  approval_request_id uuid,   -- FK added in 0031 once approval_requests exists
  status text not null default 'completed'
    check (status in ('pending_approval','approved','rejected','completed','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.users_profile(id),
  updated_by uuid references public.users_profile(id),
  deleted_at timestamptz,
  deleted_by uuid references public.users_profile(id)
);

create index idx_transactions_fy on public.transactions(financial_year_id) where deleted_at is null;
create index idx_transactions_project on public.transactions(project_id) where project_id is not null;
create index idx_transactions_activity on public.transactions(activity_id) where activity_id is not null;
create index idx_transactions_status on public.transactions(status);

create trigger trg_transactions_updated_at
  before update on public.transactions
  for each row execute function public.set_updated_at();

create trigger trg_audit_transactions
  after insert or update or delete on public.transactions
  for each row execute function public.audit_row_change();

create trigger trg_transactions_closed_year_guard
  before insert or update on public.transactions
  for each row execute function public.enforce_financial_year_not_closed();

-- Section 20: "receipt PDF generation is a future feature, but the database
-- must already contain the necessary receipt fields." pdf_storage_path stays
-- null until that Edge Function exists.
create table public.receipts (
  id uuid primary key default gen_random_uuid(),
  related_entity_type text not null check (related_entity_type in ('transaction','membership_fee_payment','donation')),
  related_entity_id uuid not null,
  receipt_number text not null unique,
  issued_at timestamptz not null default now(),
  issued_by uuid references public.users_profile(id),
  pdf_storage_path text
);

create index idx_receipts_entity on public.receipts(related_entity_type, related_entity_id);

create table public.invoices (
  id uuid primary key default gen_random_uuid(),
  partner_id uuid references public.partners(id),
  invoice_number text not null unique,
  amount numeric(14,2) not null check (amount >= 0),
  issued_date date not null default current_date,
  due_date date,
  status text not null default 'unpaid' check (status in ('unpaid','paid','cancelled')),
  notes text,
  storage_path text,
  created_at timestamptz not null default now(),
  created_by uuid references public.users_profile(id)
);
