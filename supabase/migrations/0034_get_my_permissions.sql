-- 0034_get_my_permissions.sql
-- Convenience RPC for the frontend: one call to get the current user's
-- effective permission codes, instead of the client re-implementing the
-- role_permissions join itself. This is for UI purposes only (showing/hiding
-- buttons) — it grants no access; RLS (already enforced at the table level
-- since Phase 1) is what actually protects the data regardless of what the
-- UI shows or hides.

create or replace function public.get_my_permissions()
returns table (code text)
language sql
stable
security definer
set search_path = public
as $$
  select distinct p.code
  from public.user_roles ur
  join public.role_permissions rp on rp.role_id = ur.role_id
  join public.permissions p on p.id = rp.permission_id
  where ur.user_id = auth_ext.current_profile_id();
$$;

grant execute on function public.get_my_permissions() to authenticated;

create or replace function public.get_my_profile()
returns public.users_profile
language sql
stable
security definer
set search_path = public
as $$
  select * from public.users_profile where id = auth_ext.current_profile_id();
$$;

grant execute on function public.get_my_profile() to authenticated;
