-- 0014_projects_activities_rls.sql
-- Phase 3: RLS for projects/activities.
-- A Membre-role user with no projects.read/activities.read permission can
-- still see the projects/activities they are personally involved in
-- (responsible or participant) — this is what Section 28's Member dashboard
-- ("relevant projects", "activities") depends on, reusing
-- auth_ext.current_member_id() from the Members module (0011).

-- ── projects ──────────────────────────────────────────────────────────────────
alter table public.projects enable row level security;

create policy projects_select on public.projects
  for select
  using (
    deleted_at is null
    and (
      auth_ext.has_permission('projects.read')
      or exists (
        select 1 from public.project_responsible pr
        where pr.project_id = projects.id and pr.member_id = auth_ext.current_member_id()
      )
    )
  );

create policy projects_insert on public.projects
  for insert with check (auth_ext.has_permission('projects.manage'));

create policy projects_update on public.projects
  for update
  using (auth_ext.has_permission('projects.manage'))
  with check (auth_ext.has_permission('projects.manage'));

-- ── project_responsible ───────────────────────────────────────────────────────
alter table public.project_responsible enable row level security;

create policy project_responsible_select on public.project_responsible
  for select
  using (auth_ext.has_permission('projects.read') or member_id = auth_ext.current_member_id());

create policy project_responsible_write on public.project_responsible
  for all
  using (auth_ext.has_permission('projects.manage'))
  with check (auth_ext.has_permission('projects.manage'));

-- ── project_milestones ─────────────────────────────────────────────────────────
alter table public.project_milestones enable row level security;

create policy project_milestones_select on public.project_milestones
  for select
  using (
    auth_ext.has_permission('projects.read')
    or exists (
      select 1 from public.project_responsible pr
      where pr.project_id = project_milestones.project_id and pr.member_id = auth_ext.current_member_id()
    )
  );

create policy project_milestones_write on public.project_milestones
  for all
  using (auth_ext.has_permission('projects.manage'))
  with check (auth_ext.has_permission('projects.manage'));

-- ── activities ────────────────────────────────────────────────────────────────
alter table public.activities enable row level security;

create policy activities_select on public.activities
  for select
  using (
    deleted_at is null
    and (
      auth_ext.has_permission('activities.read')
      or exists (
        select 1 from public.activity_responsible ar
        where ar.activity_id = activities.id and ar.member_id = auth_ext.current_member_id()
      )
      or exists (
        select 1 from public.activity_participants ap
        where ap.activity_id = activities.id and ap.member_id = auth_ext.current_member_id()
      )
    )
  );

create policy activities_insert on public.activities
  for insert with check (auth_ext.has_permission('activities.manage'));

create policy activities_update on public.activities
  for update
  using (auth_ext.has_permission('activities.manage'))
  with check (auth_ext.has_permission('activities.manage'));

-- ── activity_responsible ───────────────────────────────────────────────────────
alter table public.activity_responsible enable row level security;

create policy activity_responsible_select on public.activity_responsible
  for select
  using (auth_ext.has_permission('activities.read') or member_id = auth_ext.current_member_id());

create policy activity_responsible_write on public.activity_responsible
  for all
  using (auth_ext.has_permission('activities.manage'))
  with check (auth_ext.has_permission('activities.manage'));

-- ── activity_participants ──────────────────────────────────────────────────────
alter table public.activity_participants enable row level security;

create policy activity_participants_select on public.activity_participants
  for select
  using (
    auth_ext.has_permission('activities.read')
    or auth_ext.has_permission('activities.manage')
    or member_id = auth_ext.current_member_id()
  );

-- Participation rosters are staff-managed in V1 (no self-registration flow yet).
create policy activity_participants_write on public.activity_participants
  for all
  using (auth_ext.has_permission('activities.manage'))
  with check (auth_ext.has_permission('activities.manage'));
