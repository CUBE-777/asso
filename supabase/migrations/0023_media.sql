-- 0023_media.sql
-- Phase 6: Media (Architecture Doc Section 16).

create table public.media_albums (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  created_at timestamptz not null default now(),
  created_by uuid references public.users_profile(id)
);

create table public.media_assets (
  id uuid primary key default gen_random_uuid(),
  album_id uuid references public.media_albums(id),
  media_type text not null check (media_type in ('photo','video')),
  title text,
  storage_path text not null,
  mime_type text,
  file_size bigint,
  taken_at timestamptz,
  created_at timestamptz not null default now(),
  created_by uuid references public.users_profile(id),
  deleted_at timestamptz,
  deleted_by uuid references public.users_profile(id)
);

create index idx_media_assets_album on public.media_assets(album_id) where deleted_at is null;

create trigger trg_audit_media_assets
  after insert or update or delete on public.media_assets
  for each row execute function public.audit_row_change();

create table public.media_tags (
  id uuid primary key default gen_random_uuid(),
  name text not null unique
);

create table public.media_asset_tags (
  media_asset_id uuid not null references public.media_assets(id) on delete cascade,
  tag_id uuid not null references public.media_tags(id) on delete cascade,
  primary key (media_asset_id, tag_id)
);

create table public.media_links (
  id uuid primary key default gen_random_uuid(),
  media_asset_id uuid not null references public.media_assets(id) on delete cascade,
  entity_type text not null check (entity_type in ('member','project','activity')),
  entity_id uuid not null,
  linked_at timestamptz not null default now(),
  linked_by uuid references public.users_profile(id),
  unique (media_asset_id, entity_type, entity_id)
);

create index idx_media_links_entity on public.media_links(entity_type, entity_id);

create or replace function public.check_media_link_integrity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_exists boolean;
begin
  case new.entity_type
    when 'member'   then select exists(select 1 from public.members where id = new.entity_id) into v_exists;
    when 'project'  then select exists(select 1 from public.projects where id = new.entity_id) into v_exists;
    when 'activity' then select exists(select 1 from public.activities where id = new.entity_id) into v_exists;
    else v_exists := false;
  end case;

  if not v_exists then
    raise exception 'media_links.entity_id % does not exist in the % table', new.entity_id, new.entity_type;
  end if;
  return new;
end;
$$;

create trigger trg_check_media_link_integrity
  before insert or update on public.media_links
  for each row execute function public.check_media_link_integrity();
