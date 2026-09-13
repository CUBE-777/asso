-- 0009_members.sql
-- Phase 2: Members (Architecture Doc Section 8).
-- Membership applications stay on the public website (out of scope, Section 8);
-- staff manually create a member row here only after acceptance.

create table public.members (
  id uuid primary key default gen_random_uuid(),
  membership_number text not null unique,
  full_name text not null,
  date_of_birth date,
  email citext,
  phone text,
  address text,
  photo_path text,                 -- Storage object path, never binary data
  profession text,
  association_role text,           -- descriptive role inside the association, distinct from system `roles`
  membership_date date not null default current_date,
  current_status text not null default 'accepted'
    check (current_status in ('application','accepted','active','suspended','withdrawn')),
  notes text,

  -- Full-text search support for the global search subsystem (Section 27).
  -- Uses the 'simple' text-search config rather than 'english', since it does
  -- not try to stem words and behaves more predictably on mixed
  -- Arabic/French/English content than a language-specific config.
  search_vector tsvector generated always as (
    to_tsvector('simple',
      coalesce(full_name, '') || ' ' ||
      coalesce(membership_number, '') || ' ' ||
      coalesce(email::text, '') || ' ' ||
      coalesce(phone, '')
    )
  ) stored,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.users_profile(id),
  updated_by uuid references public.users_profile(id),
  deleted_at timestamptz,
  deleted_by uuid references public.users_profile(id)
);

create index idx_members_status on public.members(current_status) where deleted_at is null;
create index idx_members_search on public.members using gin(search_vector);
create index idx_members_name_trgm on public.members using gin (full_name gin_trgm_ops);

create trigger trg_members_updated_at
  before update on public.members
  for each row execute function public.set_updated_at();

create trigger trg_audit_members
  after insert or update or delete on public.members
  for each row execute function public.audit_row_change();

-- ── Status history (Section 8: "never overwrite important historical status
-- changes; store the complete status history") ───────────────────────────────

create table public.member_status_history (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.members(id),
  previous_status text,
  new_status text not null,
  changed_at timestamptz not null default now(),
  changed_by uuid references public.users_profile(id),
  reason text
);

create index idx_member_status_history_member on public.member_status_history(member_id, changed_at desc);

-- Auto-log: fires on every insert (captures the initial status) and on every
-- update where current_status actually changed. Application code never writes
-- to this table directly (enforced by RLS in 0011 — no insert/update/delete
-- policy is granted to any application role).
create or replace function public.log_member_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if TG_OP = 'INSERT' then
    insert into public.member_status_history (member_id, previous_status, new_status, changed_by)
    values (new.id, null, new.current_status, auth_ext.current_profile_id());
  elsif TG_OP = 'UPDATE' and new.current_status is distinct from old.current_status then
    insert into public.member_status_history (member_id, previous_status, new_status, changed_by)
    values (new.id, old.current_status, new.current_status, auth_ext.current_profile_id());
  end if;
  return new;
end;
$$;

create trigger trg_log_member_status_change
  after insert or update on public.members
  for each row execute function public.log_member_status_change();
