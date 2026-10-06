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
`authenticated`, and `20261006120000` also grants `anon`. Siri calls it
with the anon key before a user session exists. The function reads only
the composition tables, so anon still cannot see saved foods or entries.
It is `security definer` with `search_path = ''`
so it can call `normalize_food_search_text`. That normalizer keeps the
first 256 characters and does not grant `EXECUTE` to `anon`,
`authenticated`, or `public`. Search keeps the first 64 characters of
the argument, then matches the stored `normalized_name`, alias
`normalized`, and `reading` columns so the `pg_trgm` indexes can be
used. `20260928140000` stores the food code, official name, and source
attribution on `saved_foods` and the food code and official name on
`food_entries`. A trigger keeps the attribution on
`source_type = mext_sfct` rows. The trigger functions are security
invoker. `EXECUTE` is revoked from `public`, `anon`, and `authenticated`;
row writes still fire the triggers. Only `postgres`, `service_role`, or the `saved_foods` owner may
change that source. A `mext_sfct` food code must exist in
`official_foods`. Copying a visible food keeps that source, food code, official name,
and attribution when `copied_from` reaches a `mext_sfct` row directly
or through other copies. Publishing that copy without this provenance fails
when the chain is still the writer's own row or a public row. A public row
with `official_food_code` also fails unless `source_attribution` is
the canonical sentence, even when `copied_from` points somewhere else.
The reference is checked only on insert and when `copied_from` changes,
including inside `publish_saved_food`. The app upserts My Foods with
PostgREST `on_conflict=user_id,food_id` and
`Prefer: resolution=merge-duplicates`, which still runs the insert
trigger. If that user's own row already exists and `copied_from` is
unchanged, the reference check waits for the update trigger. The
existence lookup reads only `auth.uid()`'s row and locks it with
`FOR UPDATE`, so a delete that has not committed yet is not treated as
an existing row. `copied_from_owner_user_id` is
required on a new reference, and the target must be the writer's own row or a public row.
A later edit still succeeds after that source becomes private or is
deleted. `authenticated` is granted
`INSERT` and `UPDATE` on `official_food_code`, `official_food_name`,
and `source_attribution`, because PR #29 replaces the table grant with
a column list that cannot name columns added later. If that revoke runs
after these columns already exist, `20260927150000` has to grant the
three columns again. CI job `sql-pr31-then-pr29` applies this branch
first and PR #29 second, then inserts, updates, and publishes a My Food
as `authenticated`.

### Apple token revocation (`20261003200000`)

`internal.apple_refresh_tokens` keeps a Sign in with Apple refresh token
only so account deletion can ask Apple to revoke it. The table is not in
the Data API. `anon` and `authenticated` cannot read or write it.
`store_apple_refresh_token`, `read_apple_refresh_token`,
`delete_apple_refresh_token`, and `delete_own_account(uuid)` grant
`EXECUTE` to `service_role` only. The zero-argument `delete_own_account()`
is dropped so a client cannot skip revocation. Personal rows deleted are
the same as before, including workouts, purchase state, search terms, and
screen actions. Public foods stay. Existing rows are not deleted when the
migration runs. Rollback drops the token table and restores the
zero-argument function. This file is not applied to production here.

### App numeric records (`20261003190000`)

`health_workouts` stores the activity, start, end, and calories Health
already returned. It does not store steps, distance, receipts, or
tokens. `advertising_use` must stay false. `authenticated` can select,
insert, and update its own rows, and cannot delete them.
`food_entries.source_saved_food_version` is the saved-food version the
app already keeps on a meal. Existing meal rows are left null. Rollback
drops the workout table and that column only.

### Account display names (`20261003180000`)

`account_display_names` copies `profiles.display_name` when the name is
1 to 40 characters. It does not copy gender, birth date, height, weight,
receipts, or purchase tokens. `anon` has no privileges. `authenticated`
can select its own row and cannot insert, update, or delete.
`internal.sync_account_display_name` is `security definer` outside
`public`, and runs after a profile insert or a change to `display_name`.
Existing profile rows are not deleted. Rollback drops only this copy.

### Device usage tables (`20261003160000`)

`calonavi_plus_entitlements`, `food_search_queries`,
`exercise_search_queries`, and `app_screen_actions` are new tables.
`anon` has no privileges. `authenticated` can select its own rows.
Entitlements also allow insert and update. The search and screen tables
are insert-only for the client. `advertising_use` must stay false.
Rollback drops only these four tables.

### `supabase_admin` default privileges

Migration runner (`postgres`) may lack permission to
`ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin`. The hardening migration
skips safely with `NOTICE` in that case. **Always** add explicit
`REVOKE ALL` / `GRANT` on each new table and function in the same migration
that creates it.

### `seed.sql`

Local seed is for test **data** only. Never put `GRANT`, `REVOKE`,
`ALTER DEFAULT PRIVILEGES`, or schema DDL in `seed.sql`.
