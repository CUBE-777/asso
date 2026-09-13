-- 0008_auth_user_provisioning.sql
-- Phase 1: bridge Supabase Auth (auth.users) to our application profile table.
-- Every new Auth user automatically gets a users_profile row and the baseline
-- 'member' role; Admin then upgrades the role via user_roles as a separate,
-- audited action (Section 23/25) — new accounts never start privileged.

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_member_role_id uuid;
begin
  insert into public.users_profile (id, full_name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.email),
    new.email
  )
  on conflict (id) do nothing;

  select id into v_member_role_id from public.roles where code = 'member';

  if v_member_role_id is not null then
    insert into public.user_roles (user_id, role_id)
    values (new.id, v_member_role_id)
    on conflict do nothing;
  end if;

  return new;
end;
$$;

create trigger trg_handle_new_auth_user
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

comment on function public.handle_new_auth_user() is
  'Auto-provisions a users_profile + default member role for every new Supabase
   Auth signup. Elevating a user beyond "member" is always a separate, audited
   users.manage action, never implicit at signup.';
