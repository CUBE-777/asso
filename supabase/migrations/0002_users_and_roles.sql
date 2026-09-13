-- 0002_users_and_roles.sql
-- Phase 1: Identity & Access
-- One profile row per Supabase Auth user, plus a data-driven role/permission model
-- (Section 6/24: roles and permissions are DATA, not hard-coded enums, so future
-- custom roles do not require a schema change).

create table public.users_profile (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  email citext not null unique,
  phone text,
  photo_path text,                 -- Storage object path, never binary data (Section 5)
  is_active boolean not null default true,
  preferred_language text not null default 'ar' check (preferred_language in ('ar','fr','en')),
  preferred_theme text not null default 'dark' check (preferred_theme in ('dark','light')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.users_profile(id),
  updated_by uuid references public.users_profile(id),
  deleted_at timestamptz,
  deleted_by uuid references public.users_profile(id)
);

comment on table public.users_profile is
  'One row per Supabase Auth user. Never store passwords here (handled by auth.users).';

create table public.roles (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,           -- e.g. 'admin','president','secretary','treasurer','member'
  label_ar text not null,
  label_fr text not null,
  label_en text not null,
  is_system boolean not null default true,  -- seeded roles cannot be deleted via the app
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.permissions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,           -- e.g. 'members.read', 'finance.approve'
  module text not null,                -- e.g. 'members', 'finance', 'settings'
  description text,
  created_at timestamptz not null default now()
);

create table public.role_permissions (
  role_id uuid not null references public.roles(id) on delete cascade,
  permission_id uuid not null references public.permissions(id) on delete cascade,
  primary key (role_id, permission_id)
);

create table public.user_roles (
  user_id uuid not null references public.users_profile(id) on delete cascade,
  role_id uuid not null references public.roles(id) on delete restrict,
  assigned_at timestamptz not null default now(),
  assigned_by uuid references public.users_profile(id),
  primary key (user_id, role_id)
);

create index idx_users_profile_active on public.users_profile(is_active) where deleted_at is null;
create index idx_user_roles_user on public.user_roles(user_id);
create index idx_role_permissions_role on public.role_permissions(role_id);

-- updated_at maintenance trigger, reused by every future table with an updated_at column.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_users_profile_updated_at
  before update on public.users_profile
  for each row execute function public.set_updated_at();

create trigger trg_roles_updated_at
  before update on public.roles
  for each row execute function public.set_updated_at();
