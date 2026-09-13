-- 0005_phase5_tasks_rls.sql
begin;
select plan(4);

insert into auth.users (id, email) values
  ('h1111111-1111-1111-1111-111111111111', 'assignee5@test.local');
-- keeps default 'member' role -> has tasks.read (assigned-only via RLS) + tasks.update_own

insert into public.members (id, membership_number, full_name, current_status) values
  ('i1111111-1111-1111-1111-111111111111', 'MB-P5-01', 'Assignee Member', 'active');

update public.users_profile set member_id = 'i1111111-1111-1111-1111-111111111111'
  where id = 'h1111111-1111-1111-1111-111111111111';

insert into public.tasks (id, title, responsible_member_id, status) values
  ('j1111111-1111-1111-1111-111111111111', 'Assigned Task', 'i1111111-1111-1111-1111-111111111111', 'todo');
insert into public.tasks (id, title, status) values
  ('j2222222-2222-2222-2222-222222222222', 'Unassigned Task', 'todo');

set local role authenticated;
set local request.jwt.claims = '{"sub":"h1111111-1111-1111-1111-111111111111"}';

select is(
  (select count(*)::int from public.tasks where id = 'j1111111-1111-1111-1111-111111111111'),
  1,
  'assignee can see their own assigned task'
);

select is(
  (select count(*)::int from public.tasks where id = 'j2222222-2222-2222-2222-222222222222'),
  0,
  'assignee cannot see a task assigned to someone else'
);

select lives_ok(
  $$ update public.tasks set status = 'in_progress' where id = 'j1111111-1111-1111-1111-111111111111' $$,
  'tasks.update_own can change the status of their own task'
);

select throws_ok(
  $$ update public.tasks set title = 'Retitled by non-manager' where id = 'j1111111-1111-1111-1111-111111111111' $$,
  'tasks.update_own may only change status and notes, not task ownership or scheduling fields',
  'tasks.update_own cannot change the title (column-scope trigger blocks it)'
);

select * from finish();
rollback;
