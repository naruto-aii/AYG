# Supabase migrations

## Grant hardening policy

Every migration that creates objects in `public` must set explicit privileges.
Do not assume Supabase default grants or `supabase_admin` default ACLs are safe.

### Tables and sequences

```sql
revoke all on table public.new_table from anon, authenticated;
grant select, insert, update on table public.new_table to authenticated;
-- grant anon only when a public-read RLS policy requires it (rare)
```

Use the smallest privilege set matching app usage. Prefer soft-delete (`UPDATE`)
over `DELETE` when the app does not hard-delete rows.

### Functions exposed to clients

```sql
revoke all on function public.some_rpc(...) from public, anon, authenticated;
grant execute on function public.some_rpc(...) to authenticated;
```

RLS policy helpers may grant `EXECUTE` to `anon` when policies call them, but
helpers must not query personal tables as `anon` unless unavoidable. Prefer
early return in `plpgsql` when `auth.uid() is null`.

### Internal triggers and SECURITY DEFINER RPCs

Leave owned by `postgres`. Do not grant `EXECUTE` to `anon` / `authenticated`.
They run with owner privileges.

### Official foods (`20260928120000`)

`official_foods` and `official_food_aliases` are authenticated-select only.
`anon` has no privileges. `INSERT` / `UPDATE` / `DELETE` / `TRUNCATE` are
revoked from `anon` and `authenticated`. The import script writes as the
database owner. `search_official_foods` and `normalize_food_search_text`
grant `EXECUTE` to `authenticated` only. The search function keeps the
first 64 characters of the argument, then matches the stored
`normalized_name`, alias `normalized`, and `reading` columns so the
`pg_trgm` indexes can be used. `20260928140000` stores the food code,
official name, and source attribution on `saved_foods` and the food code
and official name on `food_entries`. A trigger keeps the attribution on
`source_type = mext_sfct` rows.

### `supabase_admin` default privileges

Migration runner (`postgres`) may lack permission to
`ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin`. The hardening migration
skips safely with `NOTICE` in that case. **Always** add explicit
`REVOKE ALL` / `GRANT` on each new table and function in the same migration
that creates it.

### `seed.sql`

Local seed is for test **data** only. Never put `GRANT`, `REVOKE`,
`ALTER DEFAULT PRIVILEGES`, or schema DDL in `seed.sql`.
