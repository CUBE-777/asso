-- 0022_documents.sql
-- Phase 6: Documents (Architecture Doc Section 15).
-- The actual file bytes live in Supabase Storage (private bucket); this table
-- only ever stores the object path + metadata (Section 5: "do not store
-- binary documents... in PostgreSQL").

create table public.documents (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  category text,             -- free-text classification (Section 15); a lookup
                              -- table can replace this later without breaking callers
  current_storage_path text not null,
  mime_type text,
  file_size bigint,

  search_vector tsvector generated always as (
    to_tsvector('simple', coalesce(title,'') || ' ' || coalesce(description,''))
  ) stored,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.users_profile(id),
  updated_by uuid references public.users_profile(id),
  deleted_at timestamptz,
  deleted_by uuid references public.users_profile(id)
);

create index idx_documents_category on public.documents(category) where deleted_at is null;
create index idx_documents_search on public.documents using gin(search_vector);

create trigger trg_documents_updated_at
  before update on public.documents
  for each row execute function public.set_updated_at();

create trigger trg_audit_documents
  after insert or update or delete on public.documents
  for each row execute function public.audit_row_change();

-- Defense-in-depth: RLS alone can't say "only documents.delete may set
-- deleted_at, only documents.restore may clear it" — this trigger enforces
-- that column-level rule regardless of which broader update policy let the
-- statement through (same pattern as enforce_task_update_own_scope in 0020).
create or replace function public.enforce_document_delete_restore_scope()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.deleted_at is distinct from old.deleted_at then
    if new.deleted_at is not null and not auth_ext.has_permission('documents.delete') then
      raise exception 'documents.delete permission is required to soft-delete a document';
    end if;
    if new.deleted_at is null and old.deleted_at is not null and not auth_ext.has_permission('documents.restore') then
      raise exception 'documents.restore permission is required to restore a document';
    end if;
  end if;
  return new;
end;
$$;

create trigger trg_enforce_document_delete_restore_scope
  before update on public.documents
  for each row execute function public.enforce_document_delete_restore_scope();

-- Versioning: a new upload creates a new Storage object + a new row here; the
-- old object/row is retained, never overwritten in place (Section 15).
create table public.document_versions (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.documents(id) on delete cascade,
  version_number int not null,
  storage_path text not null,
  mime_type text,
  file_size bigint,
  uploaded_at timestamptz not null default now(),
  uploaded_by uuid references public.users_profile(id),
  notes text,
  unique (document_id, version_number)
);

create index idx_document_versions_document on public.document_versions(document_id, version_number desc);

-- Polymorphic link: a document can attach to any of these entity types.
create table public.document_links (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.documents(id) on delete cascade,
  entity_type text not null check (entity_type in
    ('member','project','activity','partner','beneficiary','meeting','transaction')),
  entity_id uuid not null,
  linked_at timestamptz not null default now(),
  linked_by uuid references public.users_profile(id),
  unique (document_id, entity_type, entity_id)
);

create index idx_document_links_entity on public.document_links(entity_type, entity_id);

-- Referential-integrity substitute for the polymorphic FK (Architecture Doc
-- Section 17.1): Postgres can't enforce "entity_id exists in the right table"
-- across a variable target, so a trigger does it explicitly.
create or replace function public.check_document_link_integrity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_exists boolean;
begin
  case new.entity_type
    when 'member'      then select exists(select 1 from public.members where id = new.entity_id) into v_exists;
    when 'project'      then select exists(select 1 from public.projects where id = new.entity_id) into v_exists;
    when 'activity'     then select exists(select 1 from public.activities where id = new.entity_id) into v_exists;
    when 'partner'      then select exists(select 1 from public.partners where id = new.entity_id) into v_exists;
    when 'beneficiary'  then select exists(select 1 from public.beneficiaries where id = new.entity_id) into v_exists;
    when 'meeting'      then select exists(select 1 from public.meetings where id = new.entity_id) into v_exists;
    -- 'transaction' validated once the finance module (Phase 7) creates that table;
    -- until then, linking to a transaction is rejected outright.
    else v_exists := false;
  end case;

  if not v_exists then
    raise exception 'document_links.entity_id % does not exist in the % table', new.entity_id, new.entity_type;
  end if;

  return new;
end;
$$;

create trigger trg_check_document_link_integrity
  before insert or update on public.document_links
  for each row execute function public.check_document_link_integrity();
