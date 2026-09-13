-- 0007_rls_policies.sql
-- Phase 1: RLS policies for identity/access/settings tables.
-- Rule for the whole project (Architecture Doc Section 7): every table has RLS
-- enabled, no exceptions, and policies call auth_ext.has_permission() rather than
-- re-implementing the join.

-- ── users_profile ────────────────────────────────────────────────────────────
alter table public.users_profile enable row level security;

create policy users_profile_select on public.users_profile
  for select
  using (
    deleted_at is null
    and (id = auth_ext.current_profile_id() or auth_ext.has_permission('users.manage'))
  );

create policy users_profile_select_deleted on public.users_profile
  for select
  using (deleted_at is not null and auth_ext.has_permission('members.read.deleted'));

create policy users_profile_insert on public.users_profile
  for insert
  with check (auth_ext.has_permission('users.manage'));

create policy users_profile_update on public.users_profile
  for update
  using (id = auth_ext.current_profile_id() or auth_ext.has_permission('users.manage'))
  with check (id = auth_ext.current_profile_id() or auth_ext.has_permission('users.manage'));

-- No delete policy at all: hard delete of a user profile is never permitted via
-- the API. Deactivation is done through is_active/deleted_at (Section 32).

-- ── roles / permissions (reference data, seeded by migration, not editable via API in V1) ──
alter table public.roles enable row level security;
alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;

create policy roles_select on public.roles for select using (true);
create policy permissions_select on public.permissions for select using (true);
create policy role_permissions_select on public.role_permissions for select using (true);
-- Deliberately no insert/update/delete policies: changing the role→permission
-- matrix in V1 happens only through a reviewed migration (Architecture Doc
-- Section 6), never through the running application, admin included.

-- ── user_roles ────────────────────────────────────────────────────────────────
alter table public.user_roles enable row level security;

create policy user_roles_select on public.user_roles
  for select
  using (user_id = auth_ext.current_profile_id() or auth_ext.has_permission('users.manage'));

create policy user_roles_insert on public.user_roles
  for insert
  with check (auth_ext.has_permission('users.manage'));

create policy user_roles_update on public.user_roles
  for update
  using (auth_ext.has_permission('users.manage'))
  with check (auth_ext.has_permission('users.manage'));

create policy user_roles_delete on public.user_roles
  for delete
  using (auth_ext.has_permission('users.manage'));

-- ── audit_log ─────────────────────────────────────────────────────────────────
alter table public.audit_log enable row level security;

create policy audit_log_select on public.audit_log
  for select
  using (auth_ext.has_permission('audit.read'));

-- No insert/update/delete policy for any application role: rows are written
-- exclusively by the SECURITY DEFINER audit_row_change() trigger function
-- (Section 12), which bypasses RLS by virtue of being SECURITY DEFINER.

-- ── association_settings / system_settings ────────────────────────────────────
alter table public.association_settings enable row level security;
alter table public.system_settings enable row level security;

create policy association_settings_select on public.association_settings
  for select using (true);  -- non-sensitive, needed for UI branding/i18n on the login screen

create policy association_settings_update on public.association_settings
  for update
  using (auth_ext.has_permission('settings.manage'))
  with check (auth_ext.has_permission('settings.manage'));

create policy system_settings_select on public.system_settings
  for select using (true);

create policy system_settings_update on public.system_settings
  for update
  using (auth_ext.has_permission('settings.manage'))
  with check (auth_ext.has_permission('settings.manage'));
