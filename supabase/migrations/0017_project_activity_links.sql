-- 0017_project_activity_links.sql
-- Phase 4 (continued): link tables deferred from Phase 3, now that
-- partners/beneficiaries exist.

create table public.project_partners (
  project_id uuid not null references public.projects(id) on delete cascade,
  partner_id uuid not null references public.partners(id) on delete cascade,
  linked_at timestamptz not null default now(),
  linked_by uuid references public.users_profile(id),
  primary key (project_id, partner_id)
);

create table public.project_beneficiaries (
  project_id uuid not null references public.projects(id) on delete cascade,
  beneficiary_id uuid not null references public.beneficiaries(id) on delete cascade,
  linked_at timestamptz not null default now(),
  linked_by uuid references public.users_profile(id),
  primary key (project_id, beneficiary_id)
);

create table public.activity_partners (
  activity_id uuid not null references public.activities(id) on delete cascade,
  partner_id uuid not null references public.partners(id) on delete cascade,
  linked_at timestamptz not null default now(),
  linked_by uuid references public.users_profile(id),
  primary key (activity_id, partner_id)
);

create table public.activity_beneficiaries (
  activity_id uuid not null references public.activities(id) on delete cascade,
  beneficiary_id uuid not null references public.beneficiaries(id) on delete cascade,
  linked_at timestamptz not null default now(),
  linked_by uuid references public.users_profile(id),
  primary key (activity_id, beneficiary_id)
);

create index idx_project_partners_partner on public.project_partners(partner_id);
create index idx_project_beneficiaries_beneficiary on public.project_beneficiaries(beneficiary_id);
create index idx_activity_partners_partner on public.activity_partners(partner_id);
create index idx_activity_beneficiaries_beneficiary on public.activity_beneficiaries(beneficiary_id);
