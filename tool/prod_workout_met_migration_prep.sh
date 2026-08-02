#!/usr/bin/env bash
# Phase 1 prep: backup + pre-metrics + migration list + db push --dry-run
# Does NOT apply migrations, commit, push, or deploy.
#
# Usage (password never echoed):
#   export SUPABASE_DB_PASSWORD='...'
#   ./tool/prod_workout_met_migration_prep.sh
#
# Or create tool/db_password.local (gitignored, single line, no newline required).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PG_DUMP="/opt/homebrew/opt/libpq/bin/pg_dump"
PSQL="/opt/homebrew/opt/libpq/bin/psql"
PG_RESTORE="/opt/homebrew/opt/libpq/bin/pg_restore"
PROJECT_REF="${SUPABASE_PROJECT_REF:-vdzzusqisymtejcjnikb}"

CHECKSUM_FILES=(
  full_backup.dump
  schema_only.sql
  data_only.sql
  backup_metadata.txt
  pre_migration_metrics.txt
)

APP_TABLES=(
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
  alcohol_entries
)

if [[ ! -x "$PG_DUMP" || ! -x "$PSQL" || ! -x "$PG_RESTORE" ]]; then
  echo "FAIL: libpq tools not found under /opt/homebrew/opt/libpq/bin" >&2
  exit 1
fi

if [[ -z "${SUPABASE_DB_PASSWORD:-}" && -f "$ROOT/tool/db_password.local" ]]; then
  SUPABASE_DB_PASSWORD="$(<"$ROOT/tool/db_password.local")"
  export SUPABASE_DB_PASSWORD
fi

if [[ -z "${SUPABASE_DB_PASSWORD:-}" ]]; then
  echo "FAIL: SUPABASE_DB_PASSWORD is not set." >&2
  exit 1
fi

TS="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="${HOME}/Kalonavi_Backups/${TS}_pre_workout_met_migration"
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

DB_HOST="db.${PROJECT_REF}.supabase.co"
DB_URL="postgresql://postgres@${DB_HOST}:5432/postgres"
export PGPASSWORD="$SUPABASE_DB_PASSWORD"

log() { echo "[$(date -u +%H:%M:%S)] $*"; }

# Supabase CLI 2.x: --db-url and --password are mutually exclusive.
# Password must be percent-encoded inside --db-url. Never log the result.
build_supabase_cli_db_url() {
  DB_HOST="$DB_HOST" python3 - <<'PY'
import os
import urllib.parse

password = os.environ["SUPABASE_DB_PASSWORD"]
host = os.environ["DB_HOST"]
encoded = urllib.parse.quote(password, safe="")
print(f"postgresql://postgres:{encoded}@{host}:5432/postgres")
PY
}

write_cli_meta() {
  local artifact_name="$1"
  local redacted_command="$2"
  {
    echo "supabase_version=$(supabase --version 2>/dev/null || echo unknown)"
    echo "command=${redacted_command}"
    echo "note=--db-url and --password are mutually exclusive in Supabase CLI 2.x"
    echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$BACKUP_DIR/${artifact_name}.meta.txt"
}

run_supabase_cli() {
  local artifact_name="$1"
  local redacted_command="$2"
  shift 2

  write_cli_meta "$artifact_name" "$redacted_command"

  local cli_db_url
  cli_db_url="$(build_supabase_cli_db_url)"

  set +e
  "$@" --db-url "$cli_db_url" \
    >"$BACKUP_DIR/${artifact_name}.txt" \
    2>"$BACKUP_DIR/${artifact_name}.err"
  local exit_code=$?
  set -e

  unset cli_db_url

  echo "exit_code=${exit_code}" >> "$BACKUP_DIR/${artifact_name}.meta.txt"

  if [[ "$exit_code" -ne 0 ]]; then
    echo "FAIL: ${artifact_name} failed (exit ${exit_code}). Stopping without retry." >&2
    echo "See ${BACKUP_DIR}/${artifact_name}.err" >&2
    return "$exit_code"
  fi
  return 0
}

run_psql() {
  "$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 "$@"
}

run_psql_tsv() {
  "$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 -At "$@"
}

auth_probe() {
  run_psql_tsv -c "select 1;"
}

write_backup_metadata() {
  {
    echo "timestamp=${TS}"
    echo "project_ref=${PROJECT_REF}"
    echo "pg_dump_version=$("$PG_DUMP" --version)"
    echo "psql_version=$("$PSQL" --version)"
    echo "cli=prod_workout_met_migration_prep.sh"
    echo "phase=pre_workout_met_migration"
    echo "target_migrations=20260728120000,20260801180000"
  } > "$BACKUP_DIR/backup_metadata.txt"
}

write_checksum_manifest() {
  (
    cd "$BACKUP_DIR"
    shasum -a 256 "${CHECKSUM_FILES[@]}"
  ) > "$BACKUP_DIR/checksums.sha256"
}

verify_backup_artifacts() {
  log "Verifying backup artifacts"
  for f in "${CHECKSUM_FILES[@]}" checksums.sha256; do
    if [[ ! -s "$BACKUP_DIR/$f" ]]; then
      echo "FAIL: backup file missing or empty: $f" >&2
      return 1
    fi
  done
  if ! rg -q 'CREATE TABLE public.users' "$BACKUP_DIR/schema_only.sql"; then
    echo "FAIL: schema_only.sql missing public.users" >&2
    return 1
  fi
  if ! "$PG_RESTORE" --list "$BACKUP_DIR/full_backup.dump" >"$BACKUP_DIR/full_backup.list" 2>"$BACKUP_DIR/full_backup.list.err"; then
    echo "FAIL: pg_restore --list failed" >&2
    return 1
  fi
  if ! (
    cd "$BACKUP_DIR"
    shasum -a 256 -c checksums.sha256
  ) >"$BACKUP_DIR/checksum_verify.txt" 2>&1; then
    echo "FAIL: checksum verification failed" >&2
    echo "See ${BACKUP_DIR}/checksum_verify.txt" >&2
    return 1
  fi
  if rg -qi 'password' "$BACKUP_DIR/backup_metadata.txt" "$BACKUP_DIR/pre_migration_metrics.txt"; then
    echo "FAIL: password-like string found in backup metadata files" >&2
    return 1
  fi
  if rg -q 'checksums.sha256' "$BACKUP_DIR/checksums.sha256"; then
    echo "FAIL: checksum manifest must not include itself" >&2
    return 1
  fi
  log "Backup verification OK"
}

log "Project ref: ${PROJECT_REF}"
log "Backup dir: ${BACKUP_DIR}"

log "Step 0/7: DB authentication probe (single attempt)"
if ! auth_probe >/dev/null 2>"$BACKUP_DIR/auth_probe.err"; then
  echo "FAIL: DB authentication failed. Stopping without retry." >&2
  echo "See ${BACKUP_DIR}/auth_probe.err (no password logged)." >&2
  exit 1
fi
log "DB authentication OK"

row_count() {
  run_psql_tsv -c "select count(*)::text from public.${1};"
}

table_exists() {
  run_psql_tsv -c "
select exists (
  select 1 from information_schema.tables
  where table_schema = 'public' and table_name = '${1}'
);"
}

policy_names_for_table() {
  run_psql_tsv -c "
select coalesce(string_agg(pol.polname, ',' order by pol.polname), '')
from pg_policy pol
join pg_class rel on rel.oid = pol.polrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public' and rel.relname = '${1}';
"
}

policy_count_for_table() {
  run_psql_tsv -c "
select count(*)::text
from pg_policy pol
join pg_class rel on rel.oid = pol.polrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public' and rel.relname = '${1}';
"
}

trigger_count_for_table() {
  run_psql_tsv -c "
select count(*)::text
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname = '${1}'
  and not t.tgisinternal;
"
}

rls_enabled_for_table() {
  run_psql_tsv -c "
select case when c.relrowsecurity then 't' else 'f' end
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname = '${1}';
"
}

grants_for_table() {
  run_psql_tsv -c "
select coalesce(
  string_agg(grantee || ':' || privilege_type, ';' order by grantee, privilege_type),
  ''
)
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name = '${1}'
  and grantee in ('anon', 'authenticated');
"
}

log "Step 1/7: Pre-migration metrics"
{
  echo "timestamp=${TS}"
  echo "project_ref=${PROJECT_REF}"
  echo
  echo "=== target tables existence ==="
  echo -n "workout_templates_exists="
  table_exists workout_templates
  echo -n "workout_template_items_exists="
  table_exists workout_template_items
  echo
  echo "=== row counts ==="
  for table in "${APP_TABLES[@]}"; do
    echo -n "${table}_rows="
    row_count "$table"
  done
  echo
  echo "=== RLS enabled ==="
  for table in "${APP_TABLES[@]}"; do
    echo -n "${table}_rls="
    rls_enabled_for_table "$table"
  done
  echo
  echo "=== policy counts ==="
  for table in "${APP_TABLES[@]}"; do
    echo -n "${table}_policies="
    policy_count_for_table "$table"
  done
  echo
  echo "=== policy names ==="
  for table in "${APP_TABLES[@]}"; do
    echo -n "${table}_policy_names="
    policy_names_for_table "$table"
  done
  echo
  echo "=== user-defined trigger counts ==="
  for table in "${APP_TABLES[@]}"; do
    echo -n "${table}_triggers="
    trigger_count_for_table "$table"
  done
  echo
  echo "=== anon/authenticated grants ==="
  for table in "${APP_TABLES[@]}"; do
    echo -n "${table}_grants="
    grants_for_table "$table"
  done
  echo
  echo "=== exercise_entries column list ==="
  run_psql_tsv -c "
select column_name || ':' || data_type || ':' || is_nullable
from information_schema.columns
where table_schema = 'public' and table_name = 'exercise_entries'
order by ordinal_position;
"
  echo
  echo "=== exercise_entries comparison snapshot (hash only) ==="
  run_psql_tsv -c "
select
  count(*)::text || '|' ||
  coalesce(
    encode(
      sha256(
        convert_to(
          coalesce(
            string_agg(
              user_id::text || ':' || entry_id || ':' ||
              coalesce(burned_kcal::text, '') || ':' ||
              coalesce(duration_min::text, ''),
              ',' order by user_id, entry_id
            ),
            ''
          ),
          'UTF8'
        )
      ),
      'hex'
    ),
    'empty'
  )
from public.exercise_entries;
"
} > "$BACKUP_DIR/pre_migration_metrics.txt"

log "Step 2/7: Full backup (schema + data + custom)"
"$PG_DUMP" "$DB_URL" --format=custom --file="$BACKUP_DIR/full_backup.dump"
"$PG_DUMP" "$DB_URL" --schema-only --file="$BACKUP_DIR/schema_only.sql"
"$PG_DUMP" "$DB_URL" --data-only --file="$BACKUP_DIR/data_only.sql"

log "Step 3/7: Backup metadata (written after all backup files)"
write_backup_metadata

log "Step 4/7: Checksum manifest (checksums.sha256 is not self-listed)"
write_checksum_manifest

log "Step 5/7: Backup verification gate"
if ! verify_backup_artifacts; then
  echo "FAIL: backup verification gate failed. Stopping before migration list/dry-run." >&2
  exit 1
fi

log "Step 6/7: supabase migration list"
if ! run_supabase_cli migration_list \
  "supabase migration list --db-url postgresql://postgres:***@${DB_HOST}:5432/postgres" \
  supabase migration list; then
  exit 1
fi
cat "$BACKUP_DIR/migration_list.txt"

log "Step 7/7: supabase db push --dry-run"
if ! run_supabase_cli db_push_dry_run \
  "supabase db push --dry-run --db-url postgresql://postgres:***@${DB_HOST}:5432/postgres" \
  supabase db push --dry-run; then
  exit 1
fi
cat "$BACKUP_DIR/db_push_dry_run.txt"

if rg -qi 'would push|applying migration|pending' "$BACKUP_DIR/db_push_dry_run.txt"; then
  UNEXPECTED="$(rg -o '202607[0-9]{10}|202608[0-9]{10}' "$BACKUP_DIR/db_push_dry_run.txt" | sort -u | rg -v '20260728120000|20260801180000' || true)"
  if [[ -n "$UNEXPECTED" ]]; then
    echo "FAIL: dry-run includes unexpected migration version(s):" >&2
    echo "$UNEXPECTED" >&2
    echo "See ${BACKUP_DIR}/db_push_dry_run.txt" >&2
    exit 2
  fi
fi
if ! rg -q '20260728120000' "$BACKUP_DIR/db_push_dry_run.txt" || ! rg -q '20260801180000' "$BACKUP_DIR/db_push_dry_run.txt"; then
  echo "WARN: expected target migrations not clearly listed in dry-run output." >&2
  echo "Review ${BACKUP_DIR}/db_push_dry_run.txt manually." >&2
fi

log "Phase 1 prep complete. No production migration applied."
log "Artifacts: ${BACKUP_DIR}"
