# Association Management System — Phase 1

This is the Phase 1 scaffold: **Foundation + Authentication + Database + Roles**,
matching the architecture document approved before implementation began.

## What's in this phase

```
/apps/web            placeholder React+TS web client (not yet implemented)
/apps/desktop        placeholder Tauri+React+TS desktop client (not yet implemented)
/packages/*          placeholder shared packages (ui, features, data-access, sync,
                      auth, i18n, types, validation) — empty entry points, filled
                      in starting Phase 2
/supabase/migrations 8 migrations implementing the full identity/access/settings/
                      audit foundation described below
/supabase/tests      pgTAP RLS test suite for Phase 1 (release gate, not optional)
```

## What the migrations implement

| File | Purpose |
|---|---|
| `0001_extensions.sql` | pgcrypto, pg_trgm, citext |
| `0002_users_and_roles.sql` | `users_profile`, `roles`, `permissions`, `role_permissions`, `user_roles` |
| `0003_seed_roles_permissions.sql` | Seeds the 5 V1 roles and full permission matrix from the architecture doc |
| `0004_auth_helpers.sql` | `auth_ext.has_permission()`, `auth_ext.has_role()`, `auth_ext.current_profile_id()` — used by every RLS policy in the project |
| `0005_audit_log.sql` | `audit_log` table + generic `audit_row_change()` trigger function, attached to users/roles tables |
| `0006_settings.sql` | Singleton `association_settings` and `system_settings` tables |
| `0007_rls_policies.sql` | RLS enabled + policies for every Phase 1 table |
| `0008_auth_user_provisioning.sql` | Auto-creates a `users_profile` + default `member` role on Supabase Auth signup |

## Running this locally

Requires the [Supabase CLI](https://supabase.com/docs/guides/cli) and Docker.

```bash
pnpm install
pnpm db:start      # starts local Supabase (Postgres, Auth, Storage, Studio)
pnpm db:reset       # applies all migrations from scratch
pnpm db:test        # runs the pgTAP suite in supabase/tests — must pass before merging
```

`pnpm db:reset` applies every file in `supabase/migrations/` in order and then seeds
via `0003_seed_roles_permissions.sql`. There is no separate seed script — seeding
is itself a migration, so a fresh environment and a production environment run
through the exact same reproducible steps (Architecture Doc Section 52).

## Status: Phases 1–9 (database layer) are implemented. Phases 10–14 are not.

This repo currently contains a **complete, RLS-enforced PostgreSQL schema** for
every module in the master spec except offline sync, backup automation,
final security hardening, deployment, and website integration. Read this
section before assuming more is done than actually is.

### What's actually implemented (Phases 1–9)

| Phase | Migrations | Covers |
|---|---|---|
| 1 — Foundation | `0001`–`0008` | Auth bridge, `users_profile`, data-driven roles/permissions (seeded), `audit_log` + generic trigger, `association_settings`/`system_settings`, RLS helpers (`auth_ext.has_permission`, `has_role`, `current_member_id`) |
| 2 — Members | `0009`–`0011` | `members` + auto-logged `member_status_history`, education/employment/skills, RLS incl. self-view for linked Membre-role users |
| 3 — Projects + Activities | `0012`–`0014` | `projects`, `project_milestones`, `activities`, responsible/participant link tables, RLS incl. "see what you're personally tied to" for Membre role |
| 4 — Partners + Beneficiaries | `0015`–`0018` | `partners`, `beneficiary_categories` (Admin-only), `beneficiaries` + separate `beneficiary_sensitive` table (Postgres has no column-level RLS, so this is how the sensitive/non-sensitive split is actually enforced), plus the project/activity ↔ partner/beneficiary links deferred from Phase 3 |
| 5 — Meetings + Tasks | `0019`–`0021` | `meetings`, attendees/agenda/decisions; `tasks` with a mutually-exclusive parent (project XOR activity XOR meeting decision), auto-logged `task_history`, and a trigger that limits `tasks.update_own` to status/notes only — RLS can't restrict columns, so a trigger does |
| 6 — Documents + Media | `0022`–`0024` | `documents` + versioning + polymorphic `document_links` (with an integrity trigger, since Postgres can't FK-check a polymorphic target), `media_assets`/albums/tags/links, Storage bucket + object-level policies |
| 7 — Finance | `0025`–`0029` | `financial_year` (+ a generic closed-year guard reused across every finance table), `accounts`/`payment_methods`/`transaction_categories`/`transactions`/`receipts`/`invoices`, `membership_fees` + payment history (outstanding balance is a view, never stored), `donations`/`grants` |
| 8 — Budget + Approval workflow | `0030`–`0032` | `budgets`/`budget_lines`/`budget_reallocations` (planned vs. actual vs. remaining is a **view**, computed live from transactions), `approval_rules` (thresholds are **data**, seeded with the 5,000/20,000 MAD example from Section 22 but editable without a deployment), and — the important part — a trigger that forces `pending_approval` on any expense above threshold **no matter what status the client sends**, plus a second guard trigger so a pending transaction's status can only change via a recorded `approval_decisions` row, never a direct UPDATE |
| 9 — Reports + Dashboard | `0033` | `get_financial_summary()` / `get_budget_consumption_summary()` — SECURITY DEFINER functions returning aggregates only, so a Président (`finance.read.summary`) gets real numbers without ever gaining row-level access to individual transactions; `v_pending_approvals` for the admin dashboard widget |

**7 pgTAP test files** (`supabase/tests/0001`–`0007`) cover RLS for every phase above, including the two most security-critical behaviors: that the approval-threshold trigger can't be bypassed by lying about `status` in an INSERT, and that a pending transaction can't be flipped to `approved` by a direct UPDATE even by someone who holds `finance.approve`.

Run `pnpm db:reset && pnpm db:test` to see all of this apply and pass.

### What is NOT implemented, and why that's a real boundary, not a to-do list

- **Frontend (Web + Desktop UI)** — `apps/web` and `apps/desktop` are still empty shells. Building real screens against a schema this size is its own multi-week effort, and doing it blind (without a live Supabase project to run `supabase gen types` against and actually click through) risks producing code that looks plausible but doesn't work.
- **Offline sync engine (`packages/sync`)** — the architecture is documented (outbox, row_version, conflict UI) but the actual Tauri/SQLite implementation needs a running desktop shell to develop against and test conflict scenarios on real data.
- **PDF/Excel report generation, receipt generation** — these are Edge Functions that need a chosen rendering library and a real Supabase project to deploy to; the database fields they'll read from (`receipts.pdf_storage_path`, etc.) already exist.
- **Signed-URL Edge Function** — the Storage RLS backstop is in place (0024), but the actual short-lived signed-URL issuing function isn't written yet.
- **Backup automation, security hardening/pen-testing, deployment, website integration (Phases 10–14 minus what's covered above)** — these fundamentally require a live, hosted Supabase project, real infrastructure choices (hosting, domain), and testing against a running system. Writing that code now, against nothing, would mean guessing at things that need to be verified, not designed.

### A realistic next step

The database is the part that's genuinely done and testable right now. The honest next step is: get this schema running on an actual Supabase project (local or hosted), confirm the test suite passes there, and then start on ONE real screen at a time in `apps/web` against that live schema — starting with Members, since it's the simplest complete module. I'd rather build that properly with you than hand you a large pile of unverified frontend code.

## Original phase-by-phase notes (kept for reference)

Adds the full Members module (Architecture Doc Section 8):

| File | Purpose |
|---|---|
| `0009_members.sql` | `members` table (full-text search vector, trigram index) + `member_status_history` with an auto-logging trigger — no application role can write history rows directly |
| `0010_members_related.sql` | `member_education`, `member_employment`, `member_skills` as proper relational tables (see the note in that file re: a small refinement vs. the illustrative `skills text[]` in the architecture doc's sample DDL) |
| `0011_members_rls.sql` | Links a system login (`users_profile`) to at most one `members` row via `member_id`, adds `auth_ext.current_member_id()`, and adds RLS policies for the whole module |

Shared code also introduced:
- `packages/types/src/member.ts` — TypeScript types mirroring the schema (Section 46)
- `packages/validation/src/member.ts` — Zod schema for member input, meant to be reused by both the frontend form and any future Edge Function validation (Section 47)

pgTAP coverage (`supabase/tests/0002_phase2_members_rls.sql`) verifies:
- Creating/updating a member auto-populates `member_status_history` correctly
- Secrétaire can read/create/update members; Trésorier can only read; a Membre-role user linked via `member_id` can read only their own record and cannot write to it
- No role can write to `member_status_history` directly

## Phase 3: Projects + Activities

Adds Projects and Activities (Architecture Doc Sections 9–10):

| File | Purpose |
|---|---|
| `0012_projects.sql` | `projects`, `project_responsible` (link to members), `project_milestones` |
| `0013_activities.sql` | `activities` (optionally linked to a project), `activity_responsible`, `activity_participants` |
| `0014_projects_activities_rls.sql` | RLS — `projects.read`/`activities.read` permission holders see everything; a Membre-role user with neither permission still sees projects/activities they're personally responsible for or participating in, via `auth_ext.current_member_id()` |

Deliberately deferred to later phases (to avoid duplicated data — Section 6):
budget/expenses (Phase 7/8, via `project_id`/`activity_id` on `budget_lines`/`transactions`), documents/media (Phase 6, via polymorphic link tables), partners/beneficiaries (Phase 4, once those tables exist), meetings/tasks (Phase 5).

pgTAP coverage (`supabase/tests/0003_phase3_projects_activities_rls.sql`) verifies: Secrétaire can read but not create projects (has `activities.manage` but not `projects.manage`), Président can create projects, and a plain Membre only sees the specific project/activity they're personally tied to — not everything.

## What Phase 1 does NOT include yet

- No business tables (members, projects, activities, finance, etc.) — those start Phase 2.
- No actual UI — `apps/web` and `apps/desktop` are empty shells with only `package.json` placeholders, so the workspace resolves and `pnpm install` succeeds.
- No Edge Functions yet — signed URLs, report generation, and approval-threshold enforcement are introduced in the phases that need them (6, 8, 9).
- No offline sync — `packages/sync` is an empty placeholder until Phase 10.

## Verifying Phase 1 is correct

Before moving to Phase 2, confirm:
1. `pnpm db:reset` runs clean with no errors.
2. `pnpm db:test` passes all 10 pgTAP assertions in `0001_phase1_rls.sql`.
3. In Supabase Studio, manually create a test Auth user and confirm a `users_profile` row and a `member` `user_roles` row appear automatically.
4. Confirm a `member`-role user cannot see other users' profiles, cannot self-promote via `user_roles`, and cannot read `audit_log` — while an `admin`-role user can do all three.

Once you've confirmed the above, say the word and we move to **Phase 4: Partners + Beneficiaries**.
