-- 0018_partners_beneficiaries_rls.sql
-- Phase 4: RLS.

-- ── partners ──────────────────────────────────────────────────────────────────
alter table public.partners enable row level security;
create policy partners_select on public.partners
  for select using (deleted_at is null and auth_ext.has_permission('partners.read'));
create policy partners_select_deleted on public.partners
  for select using (deleted_at is not null and auth_ext.has_permission('partners.manage'));
create policy partners_insert on public.partners
  for insert with check (auth_ext.has_permission('partners.manage'));
create policy partners_update on public.partners
  for update using (auth_ext.has_permission('partners.manage')) with check (auth_ext.has_permission('partners.manage'));

alter table public.partner_agreements enable row level security;
create policy partner_agreements_select on public.partner_agreements
  for select using (auth_ext.has_permission('partners.read'));
create policy partner_agreements_write on public.partner_agreements
  for all using (auth_ext.has_permission('partners.manage')) with check (auth_ext.has_permission('partners.manage'));

-- ── beneficiary_categories (Admin-configurable, Section 12) ─────────────────
alter table public.beneficiary_categories enable row level security;
create policy beneficiary_categories_select on public.beneficiary_categories
  for select using (auth_ext.has_permission('beneficiaries.read'));
create policy beneficiary_categories_write on public.beneficiary_categories
  for all using (auth_ext.has_permission('settings.manage')) with check (auth_ext.has_permission('settings.manage'));

-- ── beneficiaries (base, non-sensitive) ──────────────────────────────────────
alter table public.beneficiaries enable row level security;
create policy beneficiaries_select on public.beneficiaries
  for select using (deleted_at is null and auth_ext.has_permission('beneficiaries.read'));
create policy beneficiaries_select_deleted on public.beneficiaries
  for select using (deleted_at is not null and auth_ext.has_permission('beneficiaries.manage'));
create policy beneficiaries_insert on public.beneficiaries
  for insert with check (auth_ext.has_permission('beneficiaries.manage'));
create policy beneficiaries_update on public.beneficiaries
  for update using (auth_ext.has_permission('beneficiaries.manage')) with check (auth_ext.has_permission('beneficiaries.manage'));

-- ── beneficiary_sensitive (stricter gate — Section 18.2) ─────────────────────
alter table public.beneficiary_sensitive enable row level security;
create policy beneficiary_sensitive_select on public.beneficiary_sensitive
  for select using (auth_ext.has_permission('beneficiaries.read.sensitive'));
create policy beneficiary_sensitive_write on public.beneficiary_sensitive
  for all
  using (auth_ext.has_permission('beneficiaries.manage') and auth_ext.has_permission('beneficiaries.read.sensitive'))
  with check (auth_ext.has_permission('beneficiaries.manage') and auth_ext.has_permission('beneficiaries.read.sensitive'));

alter table public.beneficiary_notes enable row level security;
create policy beneficiary_notes_select on public.beneficiary_notes
  for select using (auth_ext.has_permission('beneficiaries.read'));
create policy beneficiary_notes_insert on public.beneficiary_notes
  for insert with check (auth_ext.has_permission('beneficiaries.manage'));
-- No update/delete: notes are an append-only history, same principle as audit_log/status history.

-- ── link tables: visible to whoever can read either side ────────────────────
alter table public.project_partners enable row level security;
create policy project_partners_select on public.project_partners
  for select using (auth_ext.has_permission('projects.read') or auth_ext.has_permission('partners.read'));
create policy project_partners_write on public.project_partners
  for all using (auth_ext.has_permission('projects.manage')) with check (auth_ext.has_permission('projects.manage'));

alter table public.project_beneficiaries enable row level security;
create policy project_beneficiaries_select on public.project_beneficiaries
  for select using (auth_ext.has_permission('projects.read') or auth_ext.has_permission('beneficiaries.read'));
create policy project_beneficiaries_write on public.project_beneficiaries
  for all using (auth_ext.has_permission('projects.manage')) with check (auth_ext.has_permission('projects.manage'));

alter table public.activity_partners enable row level security;
create policy activity_partners_select on public.activity_partners
  for select using (auth_ext.has_permission('activities.read') or auth_ext.has_permission('partners.read'));
create policy activity_partners_write on public.activity_partners
  for all using (auth_ext.has_permission('activities.manage')) with check (auth_ext.has_permission('activities.manage'));

alter table public.activity_beneficiaries enable row level security;
create policy activity_beneficiaries_select on public.activity_beneficiaries
  for select using (auth_ext.has_permission('activities.read') or auth_ext.has_permission('beneficiaries.read'));
create policy activity_beneficiaries_write on public.activity_beneficiaries
  for all using (auth_ext.has_permission('activities.manage')) with check (auth_ext.has_permission('activities.manage'));
