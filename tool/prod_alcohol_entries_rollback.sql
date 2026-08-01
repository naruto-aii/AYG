-- Rollback for: 20260801120000_create_alcohol_entries.sql
-- WARNING: Drops all alcohol_entries data. Use only as a last resort.
-- Prefer app-side feature disable or code revert first.

BEGIN;

DROP TABLE IF EXISTS public.alcohol_entries;

COMMIT;
