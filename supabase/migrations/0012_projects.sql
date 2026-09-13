-- 0012_projects.sql
-- Phase 3: Projects (Architecture Doc Section 10).
--
-- Deliberately NOT included here (added in the phase that owns them, to avoid
-- duplicated data per Section 6):
--   * budget / funding sources / expenses -> budget_lines / transactions (Phase 7/8), keyed by project_id
--   * documents / media                   -> document_links / media_links (Phase 6), keyed by entity_type='project'
--   * meetings / tasks                    -> tasks.project_id / meeting FK (Phase 5)
--   * partners / beneficiaries             -> project_partners / project_beneficiaries (Phase 4, once those tables exist)

create table public.projects (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  objectives text,
  start_date date,
  end_date date,
  status text not null default 'planning'
    check (status in ('planning','active','on_hold','completed','cancelled')),
  results text,          -- narrative outcome, filled in as the project progresses/closes
  notes text,

  search_vector tsvector generated always as (
    to_tsvector('simple', coalesce(name,'') || ' ' || coalesce(description,''))
  ) stored,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.users_profile(id),
  updated_by uuid references public.users_profile(id),
  deleted_at timestamptz,
  deleted_by uuid references public.users_profile(id),

  check (end_date is null or start_date is null or end_date >= start_date)
);

create index idx_projects_status on public.projects(status) where deleted_at is null;
create index idx_projects_search on public.projects using gin(search_vector);

create trigger trg_projects_updated_at
  before update on public.projects
  for each row execute function public.set_updated_at();

create trigger trg_audit_projects
  after insert or update or delete on public.projects
  for each row execute function public.audit_row_change();

-- Who is responsible for a project (Section 10: "Responsible people" — plural,
-- hence a link table rather than a single FK column).
create table public.project_responsible (
  project_id uuid not null references public.projects(id) on delete cascade,
  member_id uuid not null references public.members(id),
  assigned_at timestamptz not null default now(),
  assigned_by uuid references public.users_profile(id),
  primary key (project_id, member_id)
);

create index idx_project_responsible_member on public.project_responsible(member_id);

-- Milestones / stages (Section 10).
create table public.project_milestones (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  title text not null,
  description text,
  due_date date,
  completed_at timestamptz,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.users_profile(id),
  updated_by uuid references public.users_profile(id)
);

create index idx_project_milestones_project on public.project_milestones(project_id, sort_order);

create trigger trg_project_milestones_updated_at
  before update on public.project_milestones
  for each row execute function public.set_updated_at();
