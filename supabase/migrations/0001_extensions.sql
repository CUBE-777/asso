-- 0001_extensions.sql
-- Phase 1: Foundation
-- Enables required Postgres extensions used across the whole schema.

create extension if not exists "pgcrypto";   -- gen_random_uuid()
create extension if not exists "pg_trgm";    -- trigram search (global search, Section 27)
create extension if not exists "citext";     -- case-insensitive text for emails

-- Convention comment (not enforced by Postgres, documented for every future migration):
--   * every business table: id uuid pk default gen_random_uuid()
--   * created_at / updated_at timestamptz not null default now()
--   * created_by / updated_by uuid references users_profile(id)
--   * deleted_at / deleted_by for soft-deletable tables
--   * all monetary columns: numeric(14,2), never float/double precision
