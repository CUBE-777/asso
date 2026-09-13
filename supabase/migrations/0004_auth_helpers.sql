-- 0004_auth_helpers.sql
-- Phase 1: RLS helper functions (Architecture Doc Section 7).
-- These are SECURITY DEFINER so they can read role/permission tables regardless
-- of the calling user's own RLS visibility, and are the single place permission
-- logic lives -- every policy in every future migration calls these instead of
-- re-writing the join.

create schema if not exists auth_ext;  -- avoid touching Supabase's reserved "auth" schema directly

create or replace function auth_ext.current_profile_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from public.users_profile
  where id = auth.uid() and deleted_at is null and is_active = true;
$$;

create or replace function auth_ext.has_permission(perm text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles ur
    join public.role_permissions rp on rp.role_id = ur.role_id
    join public.permissions p on p.id = rp.permission_id
    where ur.user_id = auth_ext.current_profile_id()
      and p.code = perm
  );
$$;

create or replace function auth_ext.has_role(role_code text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles ur
    join public.roles r on r.id = ur.role_id
    where ur.user_id = auth_ext.current_profile_id()
      and r.code = role_code
  );
$$;

comment on function auth_ext.has_permission(text) is
  'Single source of truth for permission checks. Every RLS policy must call this
   rather than re-implementing the role/permission join.';
