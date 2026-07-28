#!/usr/bin/env bash
# Production migration: saved_foods.serving_unit_label only.
#
# Applies ONLY:
#   supabase/migrations/20260729120000_add_saved_foods_serving_unit_label.sql
#
# Does NOT re-run v1.1 food-master migrations.
#
# Usage:
#   # Backup only (default)
#   ./tool/prod_serving_unit_label_migration.sh
#
#   # Backup + apply migration
#   APPLY_MIGRATION=yes ./tool/prod_serving_unit_label_migration.sh
#
# Prerequisites:
#   export SUPABASE_DB_PASSWORD='...'
#   Optional: export SUPABASE_PROJECT_REF='...'
#   Or: tool/db_password.local (gitignored — see .gitignore)
#
# Secrets are never echoed. Password is passed via PGPASSWORD only.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PG_DUMP="/opt/homebrew/opt/libpq/bin/pg_dump"
PSQL="/opt/homebrew/opt/libpq/bin/psql"
MIGRATION_FILE="$ROOT/supabase/migrations/20260729120000_add_saved_foods_serving_unit_label.sql"

if [[ ! -x "$PG_DUMP" ]]; then
  echo "FAIL: pg_dump not found at $PG_DUMP" >&2
  exit 1
fi

if [[ ! -x "$PSQL" ]]; then
  echo "FAIL: psql not found at $PSQL" >&2
  exit 1
fi

if [[ ! -f "$MIGRATION_FILE" ]]; then
  echo "FAIL: migration file not found: $MIGRATION_FILE" >&2
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

run_psql_tsv() {
  "$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 -At "$@"
}

log "Project ref: ${PROJECT_REF}"
log "Backup dir: ${BACKUP_DIR}"
log "Migration target: 20260729120000_add_saved_foods_serving_unit_label.sql"

log "Step 1/8: Pre-migration schema probe"
run_psql -c "
select exists (
  select 1 from information_schema.tables
  where table_schema = 'public' and table_name = 'saved_foods'
) as saved_foods_exists,
exists (
  select 1 from information_schema.columns
  where table_schema = 'public'
    and table_name = 'saved_foods'
    and column_name = 'serving_unit_label'
) as serving_unit_label_exists;
" | tee "$BACKUP_DIR/pre_migration_schema_probe.txt"

SAVED_FOODS_EXISTS="$(run_psql_tsv -c "
select exists (
  select 1 from information_schema.tables
  where table_schema = 'public' and table_name = 'saved_foods'
);
")"

if [[ "$SAVED_FOODS_EXISTS" != "t" ]]; then
  echo "FAIL: public.saved_foods does not exist. Apply v1.1 migrations first." >&2
  exit 1
fi

SERVING_UNIT_LABEL_EXISTS="$(run_psql_tsv -c "
select exists (
  select 1 from information_schema.columns
  where table_schema = 'public'
    and table_name = 'saved_foods'
    and column_name = 'serving_unit_label'
);
")"

log "Step 2/8: Pre-migration counts (saved_foods rows + RLS/Policy/Trigger)"
{
  echo "=== saved_foods row count ==="
  run_psql -c "select count(*) as saved_foods_row_count from public.saved_foods;"
  echo
  echo "=== saved_foods RLS enabled ==="
  run_psql -c "
select c.relname as table_name, c.relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname = 'saved_foods';
"
  echo
  echo "=== saved_foods policy count ==="
  run_psql -c "
select count(*) as policy_count
from pg_policy pol
join pg_class rel on rel.oid = pol.polrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public' and rel.relname = 'saved_foods';
"
  echo
  echo "=== saved_foods trigger count (user-defined) ==="
  run_psql -c "
select count(*) as trigger_count
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname = 'saved_foods'
  and not t.tgisinternal;
"
  echo
  echo "=== key table row counts ==="
  run_psql -c "
select 'users' as tbl, count(*) from public.users
union all select 'food_entries', count(*) from public.food_entries
union all select 'saved_foods', count(*) from public.saved_foods
order by 1;
"
} | tee "$BACKUP_DIR/pre_migration_counts.txt"

PRE_SAVED_FOODS_COUNT="$(run_psql_tsv -c "select count(*) from public.saved_foods;")"
PRE_POLICY_COUNT="$(run_psql_tsv -c "
select count(*)::text
from pg_policy pol
join pg_class rel on rel.oid = pol.polrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public' and rel.relname = 'saved_foods';
")"
PRE_TRIGGER_COUNT="$(run_psql_tsv -c "
select count(*)::text
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname = 'saved_foods'
  and not t.tgisinternal;
")"
PRE_RLS_ENABLED="$(run_psql_tsv -c "
select c.relrowsecurity::text
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname = 'saved_foods';
")"

log "Step 3/8: Full backup (schema + data)"
"$PG_DUMP" "$DB_URL" --format=custom --file="$BACKUP_DIR/full_backup.dump"
"$PG_DUMP" "$DB_URL" --schema-only --file="$BACKUP_DIR/schema_only.sql"
"$PG_DUMP" "$DB_URL" --data-only --file="$BACKUP_DIR/data_only.sql"

log "Step 4/8: Backup metadata + checksums"
{
  echo "timestamp=${TS}"
  echo "project_ref=${PROJECT_REF}"
  echo "pg_dump_version=$("$PG_DUMP" --version)"
  echo "psql_version=$("$PSQL" --version)"
  echo "cli=prod_serving_unit_label_migration.sh"
  echo "migration=20260729120000_add_saved_foods_serving_unit_label.sql"
  echo "serving_unit_label_exists_before=${SERVING_UNIT_LABEL_EXISTS}"
} > "$BACKUP_DIR/backup_metadata.txt"

shasum -a 256 "$BACKUP_DIR"/* > "$BACKUP_DIR/checksums.sha256"

log "Step 5/8: Backup verification"
for f in full_backup.dump schema_only.sql data_only.sql checksums.sha256; do
  if [[ ! -s "$BACKUP_DIR/$f" ]]; then
    echo "FAIL: backup file missing or empty: $f" >&2
    exit 1
  fi
done
if ! rg -q 'CREATE TABLE public.saved_foods' "$BACKUP_DIR/schema_only.sql"; then
  echo "FAIL: schema_only.sql missing public.saved_foods" >&2
  exit 1
fi
shasum -a 256 -c "$BACKUP_DIR/checksums.sha256"
log "Backup verification OK"

if [[ "${APPLY_MIGRATION:-}" != "yes" ]]; then
  log "Backup complete. Set APPLY_MIGRATION=yes to apply serving_unit_label migration."
  exit 0
fi

if [[ "$SERVING_UNIT_LABEL_EXISTS" == "t" ]]; then
  log "serving_unit_label already exists — migration skipped (idempotent)."
  {
    echo "status=already_applied"
    echo "serving_unit_label_exists=true"
    echo "migration_skipped=true"
    echo
    echo "=== column definition ==="
    run_psql -c "
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name = 'saved_foods'
  and column_name = 'serving_unit_label';
"
    echo
    echo "=== saved_foods row count (unchanged) ==="
    run_psql -c "select count(*) as saved_foods_row_count from public.saved_foods;"
  } | tee "$BACKUP_DIR/post_migration_verification.txt"
  log "No changes applied. Review ${BACKUP_DIR}"
  exit 0
fi

log "Step 6/8: Apply serving_unit_label migration"
run_psql -f "$MIGRATION_FILE"

log "Step 7/8: Post-migration verification"
POST_SAVED_FOODS_COUNT="$(run_psql_tsv -c "select count(*) from public.saved_foods;")"
POST_POLICY_COUNT="$(run_psql_tsv -c "
select count(*)::text
from pg_policy pol
join pg_class rel on rel.oid = pol.polrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public' and rel.relname = 'saved_foods';
")"
POST_TRIGGER_COUNT="$(run_psql_tsv -c "
select count(*)::text
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname = 'saved_foods'
  and not t.tgisinternal;
")"
POST_RLS_ENABLED="$(run_psql_tsv -c "
select c.relrowsecurity::text
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname = 'saved_foods';
")"

{
  echo "status=applied"
  echo "migration=20260729120000_add_saved_foods_serving_unit_label.sql"
  echo
  echo "=== column definition ==="
  run_psql -c "
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name = 'saved_foods'
  and column_name = 'serving_unit_label';
"
  echo
  echo "=== serving_unit_label distribution ==="
  run_psql -c "
select
  count(*) as total_rows,
  count(serving_unit_label) as with_label,
  count(*) - count(serving_unit_label) as legacy_null
from public.saved_foods;
"
  echo
  echo "=== saved_foods row count (before -> after) ==="
  echo "before=${PRE_SAVED_FOODS_COUNT}"
  echo "after=${POST_SAVED_FOODS_COUNT}"
  run_psql -c "select count(*) as saved_foods_row_count from public.saved_foods;"
  echo
  echo "=== RLS enabled (before -> after) ==="
  echo "before=${PRE_RLS_ENABLED}"
  echo "after=${POST_RLS_ENABLED}"
  run_psql -c "
select c.relname as table_name, c.relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname = 'saved_foods';
"
  echo
  echo "=== policy count (before -> after) ==="
  echo "before=${PRE_POLICY_COUNT}"
  echo "after=${POST_POLICY_COUNT}"
  run_psql -c "
select count(*) as policy_count
from pg_policy pol
join pg_class rel on rel.oid = pol.polrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public' and rel.relname = 'saved_foods';
"
  echo
  echo "=== trigger count (before -> after) ==="
  echo "before=${PRE_TRIGGER_COUNT}"
  echo "after=${POST_TRIGGER_COUNT}"
  run_psql -c "
select count(*) as trigger_count
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname = 'saved_foods'
  and not t.tgisinternal;
"
} | tee "$BACKUP_DIR/post_migration_verification.txt"

log "Step 8/8: Post-migration assertions"
if [[ "$PRE_SAVED_FOODS_COUNT" != "$POST_SAVED_FOODS_COUNT" ]]; then
  echo "FAIL: saved_foods row count changed (${PRE_SAVED_FOODS_COUNT} -> ${POST_SAVED_FOODS_COUNT})" >&2
  exit 1
fi
if [[ "$PRE_POLICY_COUNT" != "$POST_POLICY_COUNT" ]]; then
  echo "FAIL: saved_foods policy count changed (${PRE_POLICY_COUNT} -> ${POST_POLICY_COUNT})" >&2
  exit 1
fi
if [[ "$PRE_TRIGGER_COUNT" != "$POST_TRIGGER_COUNT" ]]; then
  echo "FAIL: saved_foods trigger count changed (${PRE_TRIGGER_COUNT} -> ${POST_TRIGGER_COUNT})" >&2
  exit 1
fi
if [[ "$PRE_RLS_ENABLED" != "$POST_RLS_ENABLED" ]]; then
  echo "FAIL: saved_foods RLS setting changed (${PRE_RLS_ENABLED} -> ${POST_RLS_ENABLED})" >&2
  exit 1
fi

COLUMN_OK="$(run_psql_tsv -c "
select case
  when exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'saved_foods'
      and column_name = 'serving_unit_label'
      and data_type = 'text'
      and is_nullable = 'YES'
  ) then 'ok' else 'bad' end;
")"
if [[ "$COLUMN_OK" != "ok" ]]; then
  echo "FAIL: serving_unit_label column definition unexpected (expected text, nullable)" >&2
  exit 1
fi

log "Migration complete. Review ${BACKUP_DIR}"
