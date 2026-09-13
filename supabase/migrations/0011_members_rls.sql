-- 0011_members_rls.sql
-- Phase 2: RLS for members module, plus the optional link between a system
-- login (users_profile — the ~5 people who log in) and an association member
-- record (members — potentially many more people than have logins). Not every
-- member has a login, and not every login-holder needs to be a member, but a
-- user with the "Membre" role typically is one, and the dashboard in
-- Architecture Doc Section 28 ("Member: personal information, assigned
-- tasks...") depends on being able to resolve "this logged-in user's own
-- member record."

alter table public.users_profile
  add column member_id uuid references public.members(id),
  add constraint users_profile_member_id_unique unique (member_id);

create or replace function auth_ext.current_member_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select member_id from public.users_profile
  where id = auth_ext.current_profile_id();
$$;

-- ── members ───────────────────────────────────────────────────────────────────
alter table public.members enable row level security;

create policy members_select on public.members
  for select
  using (
    deleted_at is null
    and (auth_ext.has_permission('members.read') or id = auth_ext.current_member_id())
  );

create policy members_select_deleted on public.members
  for select
  using (deleted_at is not null and auth_ext.has_permission('members.read.deleted'));

create policy members_insert on public.members
  for insert
  with check (auth_ext.has_permission('members.create'));

create policy members_update on public.members
  for update
  using (auth_ext.has_permission('members.update'))
  with check (auth_ext.has_permission('members.update'));

-- No delete policy: members.delete is a soft-delete (sets deleted_at), which
-- is just an UPDATE covered by the policy above, gated by members.update in
-- practice at the application layer calling it only when the user also has
-- members.delete. True hard delete is never exposed via the API.

-- ── member_status_history ────────────────────────────────────────────────────
alter table public.member_status_history enable row level security;

create policy member_status_history_select on public.member_status_history
  for select
  using (
    auth_ext.has_permission('members.read')
    or member_id = auth_ext.current_member_id()
  );
-- No insert/update/delete policy: written exclusively by the SECURITY DEFINER
-- log_member_status_change() trigger (Section 8: "never overwrite important
-- historical status changes").

-- ── member_education / member_employment / member_skills ────────────────────
alter table public.member_education enable row level security;
alter table public.member_employment enable row level security;
alter table public.member_skills enable row level security;

create policy member_education_select on public.member_education
  for select using (auth_ext.has_permission('members.read') or member_id = auth_ext.current_member_id());
create policy member_education_write on public.member_education
  for all using (auth_ext.has_permission('members.update')) with check (auth_ext.has_permission('members.update'));

create policy member_employment_select on public.member_employment
  for select using (auth_ext.has_permission('members.read') or member_id = auth_ext.current_member_id());
create policy member_employment_write on public.member_employment
  for all using (auth_ext.has_permission('members.update')) with check (auth_ext.has_permission('members.update'));

create policy member_skills_select on public.member_skills
  for select using (auth_ext.has_permission('members.read') or member_id = auth_ext.current_member_id());
create policy member_skills_write on public.member_skills
  for all using (auth_ext.has_permission('members.update')) with check (auth_ext.has_permission('members.update'));
