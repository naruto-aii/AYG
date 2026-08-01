#!/usr/bin/env bash
# Production migration: public.alcohol_entries only.
#
# Applies ONLY:
#   supabase/migrations/20260801120000_create_alcohol_entries.sql
#
# Does NOT re-run v1.1 or serving_unit_label migrations.
#
# Usage:
#   # Backup only (default)
#   ./tool/prod_alcohol_entries_migration.sh
#
#   # Backup + apply migration
#   APPLY_MIGRATION=yes ./tool/prod_alcohol_entries_migration.sh
#
# Rollback (last resort — drops all alcohol data):
#   psql ... -v ON_ERROR_STOP=1 -f tool/prod_alcohol_entries_rollback.sql
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
MIGRATION_FILE="$ROOT/supabase/migrations/20260801120000_create_alcohol_entries.sql"
ROLLBACK_FILE="$ROOT/tool/prod_alcohol_entries_rollback.sql"

EXISTING_TABLES=(
  users
  profiles
  goals
  nutrition_settings
  health_snapshots
  app_settings
  food_entries
  exercise_entries
  weight_entries
  saved_foods
  meal_templates
  meal_template_items
)

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

policy_count_for_table() {
  local table="$1"
  run_psql_tsv -c "
select count(*)::text
from pg_policy pol
join pg_class rel on rel.oid = pol.polrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public' and rel.relname = '${table}';
"
}

trigger_count_for_table() {
  local table="$1"
  run_psql_tsv -c "
select count(*)::text
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname = '${table}'
  and not t.tgisinternal;
"
}

rls_enabled_for_table() {
  local table="$1"
  run_psql_tsv -c "
select case when c.relrowsecurity then 't' else 'f' end
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname = '${table}';
"
}

is_rls_enabled_value() {
  case "$1" in
    t|true|yes|1|on) return 0 ;;
    *) return 1 ;;
  esac
}

row_count_for_table() {
  local table="$1"
  run_psql_tsv -c "select count(*)::text from public.${table};"
}

capture_existing_table_metrics() {
  local prefix="$1"
  local file="$BACKUP_DIR/${prefix}_existing_table_metrics.txt"
  {
    echo "=== row counts ==="
    for table in "${EXISTING_TABLES[@]}"; do
      echo -n "${table}_rows="
      row_count_for_table "$table"
    done
    echo
    echo "=== policy counts ==="
    for table in "${EXISTING_TABLES[@]}"; do
      echo -n "${table}_policies="
      policy_count_for_table "$table"
    done
    echo
    echo "=== trigger counts (user-defined) ==="
    for table in "${EXISTING_TABLES[@]}"; do
      echo -n "${table}_triggers="
      trigger_count_for_table "$table"
    done
    echo
    echo "=== RLS enabled ==="
    for table in "${EXISTING_TABLES[@]}"; do
      echo -n "${table}_rls="
      rls_enabled_for_table "$table"
    done
  } | tee "$file"
}

read_metric() {
  local file="$1"
  local key="$2"
  rg "^${key}=" "$file" | head -1 | cut -d= -f2-
}

verify_alcohol_entries_structure() {
  echo "=== alcohol_entries table exists ==="
  run_psql -c "
select exists (
  select 1 from information_schema.tables
  where table_schema = 'public' and table_name = 'alcohol_entries'
) as alcohol_entries_exists;
"
  echo
  echo "=== alcohol_entries columns ==="
  run_psql -c "
select column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema = 'public' and table_name = 'alcohol_entries'
order by ordinal_position;
"
  echo
  echo "=== primary key ==="
  run_psql -c "
select tc.constraint_name, kcu.column_name
from information_schema.table_constraints tc
join information_schema.key_column_usage kcu
  on tc.constraint_name = kcu.constraint_name
  and tc.table_schema = kcu.table_schema
where tc.table_schema = 'public'
  and tc.table_name = 'alcohol_entries'
  and tc.constraint_type = 'PRIMARY KEY'
order by kcu.ordinal_position;
"
  echo
  echo "=== check constraints ==="
  run_psql -c "
select con.conname as constraint_name, pg_get_constraintdef(con.oid) as definition
from pg_constraint con
join pg_class rel on rel.oid = con.conrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public'
  and rel.relname = 'alcohol_entries'
  and con.contype = 'c'
order by con.conname;
"
  echo
  echo "=== indexes ==="
  run_psql -c "
select indexname, indexdef
from pg_indexes
where schemaname = 'public' and tablename = 'alcohol_entries'
order by indexname;
"
  echo
  echo "=== RLS enabled ==="
  run_psql -c "
select c.relname as table_name, c.relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname = 'alcohol_entries';
"
  echo
  echo "=== policies ==="
  run_psql -c "
select pol.polname as policy_name, pol.polcmd as command
from pg_policy pol
join pg_class rel on rel.oid = pol.polrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public' and rel.relname = 'alcohol_entries'
order by pol.polname;
"
  echo
  echo "=== table grants ==="
  run_psql -c "
select grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public' and table_name = 'alcohol_entries'
order by grantee, privilege_type;
"
  echo
  echo "=== anon grants on alcohol_entries (should be empty) ==="
  run_psql -c "
select grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name = 'alcohol_entries'
  and grantee = 'anon'
order by privilege_type;
"
}

log "Project ref: ${PROJECT_REF}"
log "Backup dir: ${BACKUP_DIR}"
log "Migration target: 20260801120000_create_alcohol_entries.sql"

log "Step 1/8: Pre-migration schema probe"
run_psql -c "
select exists (
  select 1 from information_schema.tables
  where table_schema = 'public' and table_name = 'alcohol_entries'
) as alcohol_entries_exists,
exists (
  select 1 from information_schema.routines
  where routine_schema = 'public' and routine_name = 'set_updated_at'
) as set_updated_at_exists;
" | tee "$BACKUP_DIR/pre_migration_schema_probe.txt"

SET_UPDATED_AT_EXISTS="$(run_psql_tsv -c "
select exists (
  select 1 from information_schema.routines
  where routine_schema = 'public' and routine_name = 'set_updated_at'
);
")"

if [[ "$SET_UPDATED_AT_EXISTS" != "t" ]]; then
  echo "FAIL: public.set_updated_at() does not exist. Apply base schema migrations first." >&2
  exit 1
fi

ALCOHOL_ENTRIES_EXISTS="$(run_psql_tsv -c "
select exists (
  select 1 from information_schema.tables
  where table_schema = 'public' and table_name = 'alcohol_entries'
);
")"

log "Step 2/8: Pre-migration counts (existing tables)"
capture_existing_table_metrics "pre_migration"

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
  echo "cli=prod_alcohol_entries_migration.sh"
  echo "migration=20260801120000_create_alcohol_entries.sql"
  echo "rollback=${ROLLBACK_FILE}"
  echo "alcohol_entries_exists_before=${ALCOHOL_ENTRIES_EXISTS}"
} > "$BACKUP_DIR/backup_metadata.txt"

shasum -a 256 "$BACKUP_DIR"/* > "$BACKUP_DIR/checksums.sha256"

log "Step 5/8: Backup verification"
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
shasum -a 256 -c "$BACKUP_DIR/checksums.sha256"
log "Backup verification OK"

if [[ "${APPLY_MIGRATION:-}" != "yes" ]]; then
  log "Backup complete. Set APPLY_MIGRATION=yes to apply alcohol_entries migration."
  exit 0
fi

if [[ "$ALCOHOL_ENTRIES_EXISTS" == "t" ]]; then
  log "alcohol_entries already exists — migration skipped (idempotent)."
  {
    echo "status=already_applied"
    echo "alcohol_entries_exists=true"
    echo "migration_skipped=true"
    echo
    verify_alcohol_entries_structure
    echo
    echo "=== existing table metrics (unchanged expectation) ==="
    cat "$BACKUP_DIR/pre_migration_existing_table_metrics.txt"
  } | tee "$BACKUP_DIR/post_migration_verification.txt"
  log "No changes applied. Review ${BACKUP_DIR}"
  exit 0
fi

log "Step 6/8: Apply alcohol_entries migration"
run_psql -f "$MIGRATION_FILE"

log "Step 7/8: Post-migration verification"
capture_existing_table_metrics "post_migration"

{
  echo "status=applied"
  echo "migration=20260801120000_create_alcohol_entries.sql"
  echo
  verify_alcohol_entries_structure
  echo
  echo "=== existing table metrics comparison ==="
  echo "--- pre ---"
  cat "$BACKUP_DIR/pre_migration_existing_table_metrics.txt"
  echo "--- post ---"
  cat "$BACKUP_DIR/post_migration_existing_table_metrics.txt"
} | tee "$BACKUP_DIR/post_migration_verification.txt"

log "Step 8/8: Post-migration assertions"

PRE_METRICS="$BACKUP_DIR/pre_migration_existing_table_metrics.txt"
POST_METRICS="$BACKUP_DIR/post_migration_existing_table_metrics.txt"

for table in "${EXISTING_TABLES[@]}"; do
  pre_rows="$(read_metric "$PRE_METRICS" "${table}_rows")"
  post_rows="$(read_metric "$POST_METRICS" "${table}_rows")"
  if [[ "$pre_rows" != "$post_rows" ]]; then
    echo "FAIL: ${table} row count changed (${pre_rows} -> ${post_rows})" >&2
    exit 1
  fi

  pre_policies="$(read_metric "$PRE_METRICS" "${table}_policies")"
  post_policies="$(read_metric "$POST_METRICS" "${table}_policies")"
  if [[ "$pre_policies" != "$post_policies" ]]; then
    echo "FAIL: ${table} policy count changed (${pre_policies} -> ${post_policies})" >&2
    exit 1
  fi

  pre_triggers="$(read_metric "$PRE_METRICS" "${table}_triggers")"
  post_triggers="$(read_metric "$POST_METRICS" "${table}_triggers")"
  if [[ "$pre_triggers" != "$post_triggers" ]]; then
    echo "FAIL: ${table} trigger count changed (${pre_triggers} -> ${post_triggers})" >&2
    exit 1
  fi

  pre_rls="$(read_metric "$PRE_METRICS" "${table}_rls")"
  post_rls="$(read_metric "$POST_METRICS" "${table}_rls")"
  if [[ "$pre_rls" != "$post_rls" ]]; then
    echo "FAIL: ${table} RLS setting changed (${pre_rls} -> ${post_rls})" >&2
    exit 1
  fi
done

TABLE_OK="$(run_psql_tsv -c "
select case
  when exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'alcohol_entries'
  ) then 'ok' else 'bad' end;
")"
if [[ "$TABLE_OK" != "ok" ]]; then
  echo "FAIL: alcohol_entries table missing after migration" >&2
  exit 1
fi

POLICY_COUNT="$(policy_count_for_table alcohol_entries)"
if [[ "$POLICY_COUNT" != "4" ]]; then
  echo "FAIL: alcohol_entries policy count expected 4, got ${POLICY_COUNT}" >&2
  exit 1
fi

RLS_OK="$(rls_enabled_for_table alcohol_entries)"
if ! is_rls_enabled_value "$RLS_OK"; then
  echo "FAIL: alcohol_entries RLS not enabled (got: ${RLS_OK})" >&2
  exit 1
fi

AUTH_GRANTS="$(run_psql_tsv -c "
select string_agg(privilege_type, ',' order by privilege_type)
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name = 'alcohol_entries'
  and grantee = 'authenticated';
")"
if [[ "$AUTH_GRANTS" != "DELETE,INSERT,SELECT,UPDATE" ]]; then
  echo "FAIL: authenticated grants unexpected (${AUTH_GRANTS})" >&2
  exit 1
fi

ANON_GRANTS="$(run_psql_tsv -c "
select count(*)::text
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name = 'alcohol_entries'
  and grantee = 'anon';
")"
if [[ "$ANON_GRANTS" != "0" ]]; then
  echo "FAIL: anon should have no grants on alcohol_entries" >&2
  exit 1
fi

PK_OK="$(run_psql_tsv -c "
select case
  when exists (
    select 1
    from information_schema.table_constraints tc
    where tc.table_schema = 'public'
      and tc.table_name = 'alcohol_entries'
      and tc.constraint_type = 'PRIMARY KEY'
  ) then 'ok' else 'bad' end;
")"
if [[ "$PK_OK" != "ok" ]]; then
  echo "FAIL: alcohol_entries primary key missing" >&2
  exit 1
fi

log "Migration complete. Review ${BACKUP_DIR}"
