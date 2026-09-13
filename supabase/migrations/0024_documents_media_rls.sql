-- 0024_documents_media_rls.sql
-- Phase 6: RLS for documents/media metadata, plus Supabase Storage buckets
-- and object-level policies (Architecture Doc Section 10).

-- ── documents ─────────────────────────────────────────────────────────────────
alter table public.documents enable row level security;
create policy documents_select on public.documents
  for select using (deleted_at is null and auth_ext.has_permission('documents.read'));
create policy documents_select_deleted on public.documents
  for select using (deleted_at is not null and auth_ext.has_permission('documents.restore'));
create policy documents_insert on public.documents
  for insert with check (auth_ext.has_permission('documents.upload'));
create policy documents_update on public.documents
  for update
  using (auth_ext.has_permission('documents.upload') or auth_ext.has_permission('documents.delete') or auth_ext.has_permission('documents.restore'))
  with check (auth_ext.has_permission('documents.upload') or auth_ext.has_permission('documents.delete') or auth_ext.has_permission('documents.restore'));
-- Which specific fields (title/description vs. deleted_at) each of those
-- permissions may actually touch is narrowed further by
-- enforce_document_delete_restore_scope() in 0022.

alter table public.document_versions enable row level security;
create policy document_versions_select on public.document_versions
  for select using (auth_ext.has_permission('documents.read'));
create policy document_versions_insert on public.document_versions
  for insert with check (auth_ext.has_permission('documents.upload'));

alter table public.document_links enable row level security;
create policy document_links_select on public.document_links
  for select using (auth_ext.has_permission('documents.read'));
create policy document_links_write on public.document_links
  for all using (auth_ext.has_permission('documents.upload')) with check (auth_ext.has_permission('documents.upload'));

-- ── media ─────────────────────────────────────────────────────────────────────
alter table public.media_albums enable row level security;
create policy media_albums_select on public.media_albums for select using (auth_ext.has_permission('media.read'));
create policy media_albums_write on public.media_albums for all
  using (auth_ext.has_permission('media.manage')) with check (auth_ext.has_permission('media.manage'));

alter table public.media_assets enable row level security;
create policy media_assets_select on public.media_assets
  for select using (deleted_at is null and auth_ext.has_permission('media.read'));
create policy media_assets_write on public.media_assets for all
  using (auth_ext.has_permission('media.manage')) with check (auth_ext.has_permission('media.manage'));

alter table public.media_tags enable row level security;
create policy media_tags_select on public.media_tags for select using (auth_ext.has_permission('media.read'));
create policy media_tags_write on public.media_tags for all
  using (auth_ext.has_permission('media.manage')) with check (auth_ext.has_permission('media.manage'));

alter table public.media_asset_tags enable row level security;
create policy media_asset_tags_select on public.media_asset_tags for select using (auth_ext.has_permission('media.read'));
create policy media_asset_tags_write on public.media_asset_tags for all
  using (auth_ext.has_permission('media.manage')) with check (auth_ext.has_permission('media.manage'));

alter table public.media_links enable row level security;
create policy media_links_select on public.media_links for select using (auth_ext.has_permission('media.read'));
create policy media_links_write on public.media_links for all
  using (auth_ext.has_permission('media.manage')) with check (auth_ext.has_permission('media.manage'));

-- ── Storage buckets ───────────────────────────────────────────────────────────
-- Everything is private by default (Section 5/15: "never expose private files
-- through public URLs"). A future public bucket for Section 40's website
-- integration is added only when that phase actually ships, not pre-created
-- empty here.
insert into storage.buckets (id, name, public)
values ('private', 'private', false)
on conflict (id) do nothing;

-- Object-level policies mirror the document_links/media_links metadata: a
-- user may read/write a Storage object under private/documents/... or
-- private/media/... only if they'd be allowed to read/write the metadata row
-- that points at it. Path convention: private/documents/{document_id}/...
-- and private/media/{media_asset_id}/... (Section 10).
create policy storage_documents_select on storage.objects
  for select
  using (
    bucket_id = 'private'
    and (storage.foldername(name))[1] = 'documents'
    and auth_ext.has_permission('documents.read')
  );

create policy storage_documents_insert on storage.objects
  for insert
  with check (
    bucket_id = 'private'
    and (storage.foldername(name))[1] = 'documents'
    and auth_ext.has_permission('documents.upload')
  );

create policy storage_media_select on storage.objects
  for select
  using (
    bucket_id = 'private'
    and (storage.foldername(name))[1] = 'media'
    and auth_ext.has_permission('media.read')
  );

create policy storage_media_insert on storage.objects
  for insert
  with check (
    bucket_id = 'private'
    and (storage.foldername(name))[1] = 'media'
    and auth_ext.has_permission('media.manage')
  );

-- NOTE: signed URLs for individual downloads still go through an Edge
-- Function (Architecture Doc Section 10) rather than direct client reads,
-- so expiry can be kept short; these object policies are the RLS backstop,
-- not the primary access path.
