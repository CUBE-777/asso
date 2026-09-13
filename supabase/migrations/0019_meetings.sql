-- 0019_meetings.sql
-- Phase 5: Meetings (Architecture Doc Section 13).

create table public.meetings (
  id uuid primary key default gen_random_uuid(),
  meeting_date date not null,
  start_time time,
  end_time time,
  location text,
  meeting_type text,           -- e.g. 'board','general_assembly','committee' — free text, not hard-coded enum
  status text not null default 'scheduled' check (status in ('scheduled','completed','cancelled')),
  notes text,                  -- PV/minutes summary; full minutes doc attaches via document_links (Phase 6)
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.users_profile(id),
  updated_by uuid references public.users_profile(id),
  deleted_at timestamptz,
  deleted_by uuid references public.users_profile(id)
);

create index idx_meetings_date on public.meetings(meeting_date) where deleted_at is null;

create trigger trg_meetings_updated_at
  before update on public.meetings
  for each row execute function public.set_updated_at();

create trigger trg_audit_meetings
  after insert or update or delete on public.meetings
  for each row execute function public.audit_row_change();

create table public.meeting_attendees (
  meeting_id uuid not null references public.meetings(id) on delete cascade,
  member_id uuid not null references public.members(id),
  attendance_status text not null default 'invited'
    check (attendance_status in ('invited','attended','absent','excused')),
  primary key (meeting_id, member_id)
);

create table public.meeting_agenda_items (
  id uuid primary key default gen_random_uuid(),
  meeting_id uuid not null references public.meetings(id) on delete cascade,
  title text not null,
  description text,
  sort_order int not null default 0
);

create index idx_meeting_agenda_items_meeting on public.meeting_agenda_items(meeting_id, sort_order);

create table public.meeting_decisions (
  id uuid primary key default gen_random_uuid(),
  meeting_id uuid not null references public.meetings(id) on delete cascade,
  description text not null,
  responsible_member_id uuid references public.members(id),
  created_at timestamptz not null default now(),
  created_by uuid references public.users_profile(id)
);

create index idx_meeting_decisions_meeting on public.meeting_decisions(meeting_id);
