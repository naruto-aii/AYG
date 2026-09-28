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
database owner. `search_official_foods` grants `EXECUTE` to
`authenticated` only. It is `security definer` with `search_path = ''`
so it can call `normalize_food_search_text`. That normalizer keeps the
first 256 characters and does not grant `EXECUTE` to `anon`,
`authenticated`, or `public`. Search keeps the first 64 characters of
the argument, then matches the stored `normalized_name`, alias
`normalized`, and `reading` columns so the `pg_trgm` indexes can be
used. `20260928140000` stores the food code, official name, and source
attribution on `saved_foods` and the food code and official name on
`food_entries`. A trigger keeps the attribution on
`source_type = mext_sfct` rows. The trigger functions are security
invoker, so `authenticated` is granted `EXECUTE` on them and `anon` is
not. Only `postgres`, `service_role`, or the `saved_foods` owner may
change that source. A `mext_sfct` food code must exist in
`official_foods`. Copying a visible food keeps that source, food code, official name,
and attribution when `copied_from` reaches a `mext_sfct` row directly
or through other copies. Publishing that copy without this provenance fails. A public row
with `official_food_code` also fails unless `source_attribution` is
the canonical sentence, even when `copied_from` points somewhere else.
`copied_from` must name a saved food the writer can read. `authenticated` is granted
`INSERT` and `UPDATE` on `official_food_code`, `official_food_name`,
and `source_attribution`, because PR #29 replaces the table grant with
a column list that cannot name columns added later. If that revoke runs
after these columns already exist, `20260927150000` has to grant the
three columns again. CI job `sql-pr31-then-pr29` applies this branch
first and PR #29 second, then inserts, updates, and publishes a My Food
as `authenticated`.

### `supabase_admin` default privileges

Migration runner (`postgres`) may lack permission to
`ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin`. The hardening migration
skips safely with `NOTICE` in that case. **Always** add explicit
`REVOKE ALL` / `GRANT` on each new table and function in the same migration
that creates it.

### `seed.sql`

Local seed is for test **data** only. Never put `GRANT`, `REVOKE`,
`ALTER DEFAULT PRIVILEGES`, or schema DDL in `seed.sql`.
