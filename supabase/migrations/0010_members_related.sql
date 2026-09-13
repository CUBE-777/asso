-- 0010_members_related.sql
-- Phase 2: Member education / employment / skills as proper relational tables
-- rather than free-text or arrays (Architecture Doc Section 6: "avoid storing
-- relational data as arbitrary JSON/arrays when a proper table is more
-- appropriate") — a member can have several employers or qualifications over
-- time, and this needs to stay queryable and reportable.
--
-- Note: this refines the illustrative DDL in the approved architecture doc
-- (Section 5), which sketched `skills text[]` as a shortcut for the example.
-- Given Section 3 lists member_skills as its own entity, and skills are a
-- natural candidate for future reporting ("members with skill X"), a real
-- table is the more consistent choice. Flagging this as the kind of small
-- refinement Section 55 asks to surface rather than silently apply.

create table public.member_education (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.members(id) on delete cascade,
  institution text not null,
  degree text,
  field_of_study text,
  start_date date,
  end_date date,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.users_profile(id),
  updated_by uuid references public.users_profile(id)
);

create table public.member_employment (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.members(id) on delete cascade,
  employer text not null,
  position text,
  start_date date,
  end_date date,             -- null = current position
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.users_profile(id),
  updated_by uuid references public.users_profile(id)
);

create table public.member_skills (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.members(id) on delete cascade,
  skill_name text not null,
  proficiency text check (proficiency in ('basic','intermediate','advanced','expert')),
  created_at timestamptz not null default now(),
  created_by uuid references public.users_profile(id),
  unique (member_id, skill_name)
);

create index idx_member_education_member on public.member_education(member_id);
create index idx_member_employment_member on public.member_employment(member_id);
create index idx_member_skills_member on public.member_skills(member_id);
create index idx_member_skills_name_trgm on public.member_skills using gin (skill_name gin_trgm_ops);

create trigger trg_member_education_updated_at
  before update on public.member_education
  for each row execute function public.set_updated_at();

create trigger trg_member_employment_updated_at
  before update on public.member_employment
  for each row execute function public.set_updated_at();
