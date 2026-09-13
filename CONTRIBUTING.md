# Contributing / Workflow

This project follows one rule strictly: **`main` is always in a state that
passes `pnpm db:reset` and `pnpm db:test`.** The CI workflow in
`.github/workflows/db-tests.yml` enforces this automatically on every push
and pull request that touches `supabase/**`.

## Branching model

- `main` — always green, always deployable.
- One branch per unit of work, named after the phase or feature it implements,
  e.g. `feature/phase2-members`, `fix/rls-beneficiary-sensitive`.
- Open a Pull Request into `main` even when working solo — this keeps a clear,
  reviewable history of *why* each schema/RLS decision was made, which matters
  a lot for a system this security-sensitive (Architecture Doc Section 52:
  "every schema change must be represented by a migration").

## Adding a new migration

1. Create the next-numbered file in `supabase/migrations/`
   (e.g. `0009_members.sql` after `0008_...`).
2. If the new table needs RLS (it always does — Section 7: "every table has
   RLS enabled, no exceptions"), add the policies in the same PR, not a
   follow-up one.
3. Add or extend a pgTAP test in `supabase/tests/` proving the RLS policy
   actually blocks what it should block, not just that it exists.
4. Run locally before opening the PR:
   ```bash
   pnpm db:reset
   pnpm db:test
   ```
5. Never edit an already-merged migration file. If a mistake ships, write a
   new migration that corrects it — migrations are an append-only history,
   same principle as the audit log.

## Secrets

- Copy `.env.example` to `.env.local` for local development.
- Real Supabase URL/keys go into GitHub Actions "Secrets" (repo Settings →
  Secrets and variables → Actions) once a hosted Supabase project exists —
  never into a committed file.
- The service-role key is never used by `apps/web` or `apps/desktop` code —
  only by Edge Functions and CI.
