#!/usr/bin/env bash
# Production v1.1 food-master migration (backup → verify → apply → verify).
#
# Prerequisites:
#   export SUPABASE_DB_PASSWORD='...'   # Supabase Dashboard → Database → password
#   Optional: export SUPABASE_PROJECT_REF='vdzzusqisymtejcjnikb'
#
# Secrets are never echoed. Password is passed via PGPASSWORD / env only.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PG_DUMP="/opt/homebrew/opt/libpq/bin/pg_dump"
PSQL="/opt/homebrew/opt/libpq/bin/psql"

if [[ ! -x "$PG_DUMP" ]]; then
  echo "FAIL: pg_dump not found at $PG_DUMP" >&2
  exit 1
fi

if [[ -z "${SUPABASE_DB_PASSWORD:-}" ]]; then
  if [[ -f "$ROOT/tool/db_password.local" ]]; then
    SUPABASE_DB_PASSWORD="$(<"$ROOT/tool/db_password.local")"
    export SUPABASE_DB_PASSWORD
  fi
fi

if [[ -z "${SUPABASE_DB_PASSWORD:-}" ]]; then
  echo "FAIL: SUPABASE_DB_PASSWORD is not set." >&2
  echo "Set export SUPABASE_DB_PASSWORD=... or create tool/db_password.local (gitignored)." >&2
  exit 1
fi

PROJECT_REF="${SUPABASE_PROJECT_REF:-}"
if [[ -z "$PROJECT_REF" && -f "$ROOT/tool/dart_defines.local.json" ]]; then
  PROJECT_REF="$(python3 - <<'PY' "$ROOT/tool/dart_defines.local.json"
import json, sys
url = json.load(open(sys.argv[1])).get("SUPABASE_URL", "")
print(url.replace("https://", "").split(".")[0] if url else "")
PY
)"
fi

if [[ -z "$PROJECT_REF" ]]; then
  echo "FAIL: SUPABASE_PROJECT_REF not set and could not derive from dart_defines.local.json" >&2
  exit 1
fi

DB_HOST="db.${PROJECT_REF}.supabase.co"
DB_URL="postgresql://postgres@${DB_HOST}:5432/postgres"
export PGPASSWORD="$SUPABASE_DB_PASSWORD"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="${HOME}/Kalonavi_Backups/${TS}"
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

log() { echo "[$(date -u +%H:%M:%S)] $*"; }

run_psql() {
  "$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 "$@"
}

log "Project ref: ${PROJECT_REF}"
log "Backup dir: ${BACKUP_DIR}"

log "Step 1/7: Pre-migration table counts"
run_psql -c "
select 'users' as tbl, count(*) from public.users
union all select 'profiles', count(*) from public.profiles
union all select 'goals', count(*) from public.goals
union all select 'nutrition_settings', count(*) from public.nutrition_settings
union all select 'health_snapshots', count(*) from public.health_snapshots
union all select 'app_settings', count(*) from public.app_settings
union all select 'food_entries', count(*) from public.food_entries
union all select 'exercise_entries', count(*) from public.exercise_entries
union all select 'weight_entries', count(*) from public.weight_entries
order by 1;
" | tee "$BACKUP_DIR/pre_migration_counts.txt"

log "Step 2/7: Pre-migration schema probe"
run_psql -c "
select exists (
  select 1 from information_schema.tables
  where table_schema = 'public' and table_name = 'saved_foods'
) as saved_foods_exists,
exists (
  select 1 from information_schema.tables
  where table_schema = 'public' and table_name = 'meal_templates'
) as meal_templates_exists,
exists (
  select 1 from information_schema.routines
  where routine_schema = 'public' and routine_name = 'set_updated_at'
) as set_updated_at_exists;
" | tee "$BACKUP_DIR/pre_migration_schema_probe.txt"

log "Step 3/7: Full backup (schema + data)"
"$PG_DUMP" "$DB_URL" --format=custom --file="$BACKUP_DIR/full_backup.dump"
"$PG_DUMP" "$DB_URL" --schema-only --file="$BACKUP_DIR/schema_only.sql"
"$PG_DUMP" "$DB_URL" --data-only --file="$BACKUP_DIR/data_only.sql"
"$PG_DUMP" "$DB_URL" --schema-only --schema=public | rg -i 'policy|trigger|function' > "$BACKUP_DIR/rls_functions_triggers.txt" || true

log "Step 4/7: Backup metadata + checksums"
{
  echo "timestamp=${TS}"
  echo "project_ref=${PROJECT_REF}"
  echo "pg_dump_version=$("$PG_DUMP" --version)"
  echo "psql_version=$("$PSQL" --version)"
  echo "cli=prod_v1_1_migration.sh"
} > "$BACKUP_DIR/backup_metadata.txt"

shasum -a 256 "$BACKUP_DIR"/* > "$BACKUP_DIR/checksums.sha256"

log "Step 5/7: Backup verification"
for f in full_backup.dump schema_only.sql data_only.sql checksums.sha256; do
  if [[ ! -s "$BACKUP_DIR/$f" ]]; then
    echo "FAIL: backup file missing or empty: $f" >&2
    exit 1
  fi
done
if ! rg -q 'CREATE TABLE public.users' "$BACKUP_DIR/schema_only.sql"; then
  echo "FAIL: schema_only.sql missing public.users" >&2
  exit 1
fi
if ! rg -q 'COPY public.food_entries' "$BACKUP_DIR/data_only.sql" 2>/dev/null; then
  log "WARN: data_only.sql has no food_entries COPY (table may be empty)"
fi
shasum -a 256 -c "$BACKUP_DIR/checksums.sha256"
log "Backup verification OK"

if [[ "${APPLY_MIGRATION:-}" != "yes" ]]; then
  log "Backup complete. Set APPLY_MIGRATION=yes to apply migrations."
  exit 0
fi

log "Step 6/7: Apply v1.1 migrations"
MIG1="$ROOT/supabase/migrations/20260723120000_add_food_master_public_v1_1.sql"
MIG2="$ROOT/supabase/migrations/20260727120000_add_saved_foods_version.sql"

if [[ ! -f "$MIG1" || ! -f "$MIG2" ]]; then
  echo "FAIL: migration files not found" >&2
  exit 1
fi

# Ensure set_updated_at exists (from base schema migration).
run_psql -c "
create or replace function public.set_updated_at()
returns trigger language plpgsql as \$\$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
\$\$;
"

run_psql -f "$MIG1"
run_psql -f "$MIG2"

log "Step 7/7: Post-migration verification"
run_psql -c "
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in (
    'saved_foods','meal_templates','meal_template_items',
    'food_ratings','food_rating_stats','food_reports','blocked_food_creators'
  )
order by 1;
" | tee "$BACKUP_DIR/post_migration_tables.txt"

run_psql -c "
select c.relname as table_name, c.relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('saved_foods','meal_templates','meal_template_items')
order by 1;
" | tee "$BACKUP_DIR/post_migration_rls.txt"

run_psql -c "
select indexname, tablename
from pg_indexes
where schemaname = 'public'
  and tablename in ('saved_foods','meal_templates','meal_template_items')
order by tablename, indexname;
" | tee "$BACKUP_DIR/post_migration_indexes.txt"

run_psql -c "
select pol.polname, rel.relname as table_name, pol.polcmd
from pg_policy pol
join pg_class rel on rel.oid = pol.polrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public'
  and rel.relname in (
    'saved_foods','meal_templates','meal_template_items',
    'food_ratings','food_reports','blocked_food_creators'
  )
order by rel.relname, pol.polname;
" | tee "$BACKUP_DIR/post_migration_policies.txt"

run_psql -c "
select 'users' as tbl, count(*) from public.users
union all select 'profiles', count(*) from public.profiles
union all select 'goals', count(*) from public.goals
union all select 'nutrition_settings', count(*) from public.nutrition_settings
union all select 'health_snapshots', count(*) from public.health_snapshots
union all select 'app_settings', count(*) from public.app_settings
union all select 'food_entries', count(*) from public.food_entries
union all select 'exercise_entries', count(*) from public.exercise_entries
union all select 'weight_entries', count(*) from public.weight_entries
union all select 'saved_foods', count(*) from public.saved_foods
union all select 'meal_templates', count(*) from public.meal_templates
order by 1;
" | tee "$BACKUP_DIR/post_migration_counts.txt"

log "Migration complete. Review ${BACKUP_DIR}"
