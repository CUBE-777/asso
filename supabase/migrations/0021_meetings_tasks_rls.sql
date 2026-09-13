-- 0021_meetings_tasks_rls.sql
-- Phase 5: RLS.

-- ── meetings ──────────────────────────────────────────────────────────────────
alter table public.meetings enable row level security;
create policy meetings_select on public.meetings
  for select using (deleted_at is null and auth_ext.has_permission('meetings.read'));
create policy meetings_insert on public.meetings
  for insert with check (auth_ext.has_permission('meetings.manage'));
create policy meetings_update on public.meetings
  for update using (auth_ext.has_permission('meetings.manage')) with check (auth_ext.has_permission('meetings.manage'));

alter table public.meeting_attendees enable row level security;
create policy meeting_attendees_select on public.meeting_attendees
  for select using (auth_ext.has_permission('meetings.read') or member_id = auth_ext.current_member_id());
create policy meeting_attendees_write on public.meeting_attendees
  for all using (auth_ext.has_permission('meetings.manage')) with check (auth_ext.has_permission('meetings.manage'));

alter table public.meeting_agenda_items enable row level security;
create policy meeting_agenda_items_select on public.meeting_agenda_items
  for select using (auth_ext.has_permission('meetings.read'));
create policy meeting_agenda_items_write on public.meeting_agenda_items
  for all using (auth_ext.has_permission('meetings.manage')) with check (auth_ext.has_permission('meetings.manage'));

alter table public.meeting_decisions enable row level security;
create policy meeting_decisions_select on public.meeting_decisions
  for select using (
    auth_ext.has_permission('meetings.read') or responsible_member_id = auth_ext.current_member_id()
  );
create policy meeting_decisions_write on public.meeting_decisions
  for all using (auth_ext.has_permission('meetings.manage')) with check (auth_ext.has_permission('meetings.manage'));

-- ── tasks ─────────────────────────────────────────────────────────────────────
alter table public.tasks enable row level security;

create policy tasks_select on public.tasks
  for select
  using (
    deleted_at is null
    and (
      auth_ext.has_permission('tasks.read')
      or responsible_member_id = auth_ext.current_member_id()
    )
  );

create policy tasks_insert on public.tasks
  for insert with check (auth_ext.has_permission('tasks.manage'));

create policy tasks_update on public.tasks
  for update
  using (
    auth_ext.has_permission('tasks.manage')
    or (auth_ext.has_permission('tasks.update_own') and responsible_member_id = auth_ext.current_member_id())
  )
  with check (
    auth_ext.has_permission('tasks.manage')
    or (auth_ext.has_permission('tasks.update_own') and responsible_member_id = auth_ext.current_member_id())
  );
-- Column-level scope for the update_own case is enforced by the
-- enforce_task_update_own_scope() trigger in 0020, not by RLS.

alter table public.task_history enable row level security;
create policy task_history_select on public.task_history
  for select using (
    auth_ext.has_permission('tasks.read')
    or exists (
      select 1 from public.tasks t
      where t.id = task_history.task_id and t.responsible_member_id = auth_ext.current_member_id()
    )
  );
-- No insert/update/delete policy: written exclusively by log_task_status_change().
