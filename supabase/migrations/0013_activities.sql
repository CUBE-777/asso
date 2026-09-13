-- 0013_activities.sql
-- Phase 3: Activities (Architecture Doc Section 9).
-- An activity optionally belongs to a project (Section 10: "a project can
-- contain multiple activities") but standalone activities are allowed —
-- project_id is nullable.
--
-- Same deferral rule as projects: budget/expenses, documents/media, partners,
-- beneficiaries, meetings, and tasks attach to an activity in the phase that
-- introduces those tables (Phase 4/5/6/7/8), via FK or polymorphic link, not
-- duplicated columns here.

create table public.activities (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references public.projects(id),
  name text not null,
  description text,
  activity_date date,
  start_time time,
  end_time time,
  location text,
  status text not null default 'planned'
    check (status in ('planned','ongoing','completed','cancelled')),
  results text,
  notes text,

  search_vector tsvector generated always as (
    to_tsvector('simple', coalesce(name,'') || ' ' || coalesce(description,'') || ' ' || coalesce(location,''))
  ) stored,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.users_profile(id),
  updated_by uuid references public.users_profile(id),
  deleted_at timestamptz,
  deleted_by uuid references public.users_profile(id),

  check (end_time is null or start_time is null or end_time >= start_time)
);

create index idx_activities_project on public.activities(project_id) where deleted_at is null;
create index idx_activities_date on public.activities(activity_date) where deleted_at is null;
create index idx_activities_search on public.activities using gin(search_vector);

create trigger trg_activities_updated_at
  before update on public.activities
  for each row execute function public.set_updated_at();

create trigger trg_audit_activities
  after insert or update or delete on public.activities
  for each row execute function public.audit_row_change();

-- Who is responsible for running the activity.
create table public.activity_responsible (
  activity_id uuid not null references public.activities(id) on delete cascade,
  member_id uuid not null references public.members(id),
  assigned_at timestamptz not null default now(),
  assigned_by uuid references public.users_profile(id),
  primary key (activity_id, member_id)
);

create index idx_activity_responsible_member on public.activity_responsible(member_id);

-- Who participated (Section 9: "Participants"). Distinct from "responsible" —
-- an activity has a small number of organizers and potentially many attendees.
create table public.activity_participants (
  activity_id uuid not null references public.activities(id) on delete cascade,
  member_id uuid not null references public.members(id),
  attendance_status text not null default 'registered'
    check (attendance_status in ('registered','attended','absent','cancelled')),
  registered_at timestamptz not null default now(),
  primary key (activity_id, member_id)
);

create index idx_activity_participants_member on public.activity_participants(member_id);
