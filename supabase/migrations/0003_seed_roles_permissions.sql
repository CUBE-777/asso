-- 0003_seed_roles_permissions.sql
-- Phase 1: seed data for the 5 V1 roles and the permission matrix from
-- Architecture Doc Section 6. Editing this mapping in V1 is a migration,
-- not an admin-UI feature (Section 6: "do not create a complicated role
-- builder in V1").

insert into public.roles (code, label_ar, label_fr, label_en, is_system) values
  ('admin',      'مدير النظام', 'Administrateur', 'Admin',      true),
  ('president',  'الرئيس',      'Président',      'President',  true),
  ('secretary',  'الكاتب العام','Secrétaire',     'Secretary',  true),
  ('treasurer',  'أمين المال',  'Trésorier',      'Treasurer',  true),
  ('member',     'عضو',         'Membre',         'Member',     true)
on conflict (code) do nothing;

insert into public.permissions (code, module, description) values
  ('members.read',        'members',      'View member profiles'),
  ('members.create',      'members',      'Create member profiles'),
  ('members.update',      'members',      'Edit member profiles'),
  ('members.delete',      'members',      'Soft-delete member profiles'),
  ('members.read.deleted','members',      'View soft-deleted member records (restore workflows)'),

  ('projects.read',       'projects',     'View projects'),
  ('projects.manage',     'projects',     'Create/update projects, milestones'),
  ('activities.read',     'activities',   'View activities'),
  ('activities.manage',   'activities',   'Create/update activities'),

  ('partners.read',       'partners',     'View partners'),
  ('partners.manage',     'partners',     'Create/update partners and agreements'),

  ('beneficiaries.read',           'beneficiaries', 'View beneficiary base profile'),
  ('beneficiaries.read.sensitive', 'beneficiaries', 'View sensitive beneficiary fields'),
  ('beneficiaries.manage',         'beneficiaries', 'Create/update beneficiaries'),

  ('meetings.read',       'meetings',     'View meetings, agendas, decisions'),
  ('meetings.manage',     'meetings',     'Create/update meetings, record decisions'),

  ('tasks.read',          'tasks',        'View tasks'),
  ('tasks.manage',        'tasks',        'Create/update/assign tasks'),
  ('tasks.update_own',    'tasks',        'Update status of tasks assigned to self'),

  ('documents.read',      'documents',    'View/download documents'),
  ('documents.upload',    'documents',    'Upload documents'),
  ('documents.delete',    'documents',    'Soft-delete documents'),
  ('documents.restore',   'documents',    'Restore soft-deleted documents'),

  ('media.read',          'media',        'View/download media'),
  ('media.manage',        'media',        'Upload/organize media'),

  ('finance.read',        'finance',      'View financial records'),
  ('finance.read.summary','finance',      'View high-level financial summary only'),
  ('finance.create',      'finance',      'Record transactions'),
  ('finance.approve',     'finance',      'Approve financial operations'),
  ('finance.override_closed_year', 'finance', 'Modify a closed financial year (audited)'),

  ('budget.read',         'budget',       'View budgets'),
  ('budget.manage',       'budget',       'Create/update budgets and reallocations'),

  ('settings.manage',     'settings',     'Manage association and system settings'),
  ('users.manage',        'users',        'Manage users and role assignments'),
  ('backup.manage',       'backup',       'Trigger backup/restore operations'),
  ('audit.read',          'audit',        'View full audit log'),
  ('audit.read.summary',  'audit',        'View filtered audit summary'),
  ('sync.resolve_conflicts', 'sync',      'Resolve offline sync conflicts')
on conflict (code) do nothing;

-- Admin: everything
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r cross join public.permissions p
where r.code = 'admin'
on conflict do nothing;

-- Président
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.code in (
  'members.read','members.create','members.update',
  'projects.read','projects.manage','activities.read','activities.manage',
  'partners.read','partners.manage',
  'beneficiaries.read','beneficiaries.read.sensitive','beneficiaries.manage',
  'meetings.read','meetings.manage',
  'tasks.read','tasks.manage','tasks.update_own',
  'documents.read','documents.upload',
  'media.read','media.manage',
  'finance.read.summary','finance.approve',
  'budget.read','budget.manage',
  'audit.read.summary'
) where r.code = 'president'
on conflict do nothing;

-- Secrétaire
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.code in (
  'members.read','members.create','members.update',
  'projects.read','activities.read','activities.manage',
  'partners.read',
  'meetings.read','meetings.manage',
  'tasks.read','tasks.manage','tasks.update_own',
  'documents.read','documents.upload',
  'media.read','media.manage'
) where r.code = 'secretary'
on conflict do nothing;

-- Trésorier
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.code in (
  'members.read',
  'projects.read','activities.read',
  'tasks.read','tasks.update_own',
  'documents.read','documents.upload',
  'finance.read','finance.create','finance.approve',
  'budget.read','budget.manage'
) where r.code = 'treasurer'
on conflict do nothing;

-- Membre
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.code in (
  'tasks.read','tasks.update_own',
  'documents.read'
) where r.code = 'member'
on conflict do nothing;
