#!/usr/bin/env bash
# Phase 2A: production migration history repair ONLY (applied marks).
# Does NOT run db push, migration SQL, db reset --linked, commit, push, or deploy.
#
# Usage (password never echoed):
#   export SUPABASE_DB_PASSWORD='...'
#   ./tool/prod_phase2a_migration_repair.sh
#
# Or create tool/db_password.local (gitignored, single line).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PG_DUMP="/opt/homebrew/opt/libpq/bin/pg_dump"
PSQL="/opt/homebrew/opt/libpq/bin/psql"
PG_RESTORE="/opt/homebrew/opt/libpq/bin/pg_restore"
PROJECT_REF="${SUPABASE_PROJECT_REF:-vdzzusqisymtejcjnikb}"

VERIFIED_BACKUP_DIR="${VERIFIED_BACKUP_DIR:-${HOME}/Kalonavi_Backups/20260801T134555Z_pre_workout_met_migration}"

CHECKSUM_FILES=(
  full_backup.dump
  schema_only.sql
  data_only.sql
  backup_metadata.txt
  pre_migration_metrics.txt
)

REPAIR_VERSIONS=(
  20260722130000
  20260723120000
  20260727120000
  20260729120000
  20260801120000
)

SKIP_REPAIR_VERSIONS=(
  20260728120000
  20260801180000
)

EXPECTED_DRY_RUN=(
  20260728120000
  20260801180000
  20260801200000
)

ROW_COUNT_TABLES=(
  users
  profiles
  goals
  nutrition_settings
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
OUT_DIR="${HOME}/Kalonavi_Backups/${TS}_phase2a_migration_repair"
mkdir -p "$OUT_DIR"
chmod 700 "$OUT_DIR"

DB_HOST="db.${PROJECT_REF}.supabase.co"
DB_URL="postgresql://postgres@${DB_HOST}:5432/postgres"
export PGPASSWORD="$SUPABASE_DB_PASSWORD"

log() { echo "[$(date -u +%H:%M:%S)] $*"; }

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
    echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$OUT_DIR/${artifact_name}.meta.txt"
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
    >"$OUT_DIR/${artifact_name}.txt" \
    2>"$OUT_DIR/${artifact_name}.err"
  local exit_code=$?
  set -e

  unset cli_db_url

  echo "exit_code=${exit_code}" >> "$OUT_DIR/${artifact_name}.meta.txt"

  if [[ "$exit_code" -ne 0 ]]; then
    echo "FAIL: ${artifact_name} failed (exit ${exit_code}). Stopping without retry." >&2
    echo "See ${OUT_DIR}/${artifact_name}.err" >&2
    return "$exit_code"
  fi
  return 0
}

run_psql_tsv() {
  "$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 -At "$@"
}

verify_verified_backup_readonly() {
  log "Step 1/8: verify verified backup (read-only)"
  {
    echo "verified_backup_dir=${VERIFIED_BACKUP_DIR}"
    echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$OUT_DIR/backup_verification.txt"

  for f in "${CHECKSUM_FILES[@]}" checksums.sha256; do
    if [[ ! -s "$VERIFIED_BACKUP_DIR/$f" ]]; then
      echo "FAIL: missing backup artifact: $f" >&2
      echo "missing=$f" >> "$OUT_DIR/backup_verification.txt"
      return 1
    fi
    echo "present=$f" >> "$OUT_DIR/backup_verification.txt"
  done

  if ! "$PG_RESTORE" --list "$VERIFIED_BACKUP_DIR/full_backup.dump" \
    >"$OUT_DIR/pg_restore_list.txt" 2>"$OUT_DIR/pg_restore_list.err"; then
    echo "FAIL: pg_restore --list failed" >&2
    echo "pg_restore_list=FAIL" >> "$OUT_DIR/backup_verification.txt"
    return 1
  fi
  echo "pg_restore_list=OK" >> "$OUT_DIR/backup_verification.txt"

  if ! (
    cd "$VERIFIED_BACKUP_DIR"
    shasum -a 256 -c checksums.sha256
  ) >"$OUT_DIR/checksum_verify.txt" 2>&1; then
    echo "FAIL: checksum verification failed" >&2
    echo "checksum_verify=FAIL" >> "$OUT_DIR/backup_verification.txt"
    return 1
  fi
  echo "checksum_verify=OK" >> "$OUT_DIR/backup_verification.txt"
  log "Backup verification OK"
}

collect_row_counts() {
  local label="$1"
  local file="$OUT_DIR/${label}_row_counts.txt"
  {
    echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "project_ref=${PROJECT_REF}"
    for t in "${ROW_COUNT_TABLES[@]}"; do
      local count
      count="$(run_psql_tsv -c "SELECT COUNT(*) FROM public.${t};" 2>/dev/null || echo "ERROR")"
      echo "${t}_rows=${count}"
    done
  } > "$file"
}

compare_row_counts() {
  local before="$OUT_DIR/pre_repair_row_counts.txt"
  local after="$OUT_DIR/post_repair_row_counts.txt"
  local cmp="$OUT_DIR/row_count_comparison.txt"
  {
    echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "=== pre_repair ==="
    cat "$before"
    echo "=== post_repair ==="
    cat "$after"
    echo "=== diff ==="
    for t in "${ROW_COUNT_TABLES[@]}"; do
      local b a
      b="$(rg "^${t}_rows=" "$before" | cut -d= -f2)"
      a="$(rg "^${t}_rows=" "$after" | cut -d= -f2)"
      if [[ "$b" != "$a" ]]; then
        echo "MISMATCH ${t}: pre=${b} post=${a}"
      else
        echo "OK ${t}=${b}"
      fi
    done
  } > "$cmp"

  if rg -q '^MISMATCH ' "$cmp"; then
    echo "FAIL: row count mismatch after repair" >&2
    echo "See ${cmp}" >&2
    return 1
  fi
  log "Row counts unchanged after repair"
}

verify_dry_run_three_only() {
  local txt_file="$OUT_DIR/db_push_dry_run.txt"
  local err_file="$OUT_DIR/db_push_dry_run.err"
  local migration_pattern='[0-9]{14}_[A-Za-z0-9_]+\.sql'
  local found sorted_found expected

  found="$(
    {
      [[ -f "$txt_file" ]] && cat "$txt_file"
      [[ -f "$err_file" ]] && cat "$err_file"
    } | rg -o "$migration_pattern" | cut -d_ -f1 | sort -u
  )"

  expected="$(printf '%s\n' "${EXPECTED_DRY_RUN[@]}" | sort)"
  sorted_found="$(printf '%s\n' "$found" | sed '/^$/d' | sort)"

  {
    echo "expected:"
    printf '%s\n' "${EXPECTED_DRY_RUN[@]}"
    echo "found_timestamps:"
    printf '%s\n' "$sorted_found"
    echo "sources:"
    echo "  ${txt_file}"
    echo "  ${err_file}"
  } > "$OUT_DIR/dry_run_migration_check.txt"

  if [[ "$expected" != "$sorted_found" ]]; then
    echo "FAIL: dry-run migrations do not match expected 3" >&2
    echo "See ${OUT_DIR}/dry_run_migration_check.txt" >&2
    return 1
  fi
  log "dry-run shows exactly 3 pending migrations"
}

{
  echo "phase=2a_migration_repair"
  echo "project_ref=${PROJECT_REF}"
  echo "verified_backup_dir=${VERIFIED_BACKUP_DIR}"
  echo "output_dir=${OUT_DIR}"
  echo "repair_versions=${REPAIR_VERSIONS[*]}"
  echo "skip_repair_versions=${SKIP_REPAIR_VERSIONS[*]}"
} > "$OUT_DIR/phase2a_metadata.txt"

log "Phase 2A output dir: ${OUT_DIR}"
log "Verified backup dir: ${VERIFIED_BACKUP_DIR}"

verify_verified_backup_readonly

log "Step 2/8: DB auth probe"
if ! run_psql_tsv -c "SELECT 1;" >/dev/null 2>"$OUT_DIR/auth_probe.err"; then
  echo "FAIL: DB authentication failed" >&2
  exit 1
fi
log "DB auth OK"

log "Step 3/8: pre-repair row counts"
collect_row_counts pre_repair

log "Step 4/8: migration repair (5 versions, one at a time)"
if [[ "${PHASE2A_RESUME_AFTER_REPAIR:-}" == "yes" ]]; then
  log "SKIP: PHASE2A_RESUME_AFTER_REPAIR=yes — skipping migration repair for: ${REPAIR_VERSIONS[*]}"
  {
    echo "skipped=true"
    echo "reason=PHASE2A_RESUME_AFTER_REPAIR=yes"
    echo "skipped_versions=${REPAIR_VERSIONS[*]}"
    echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$OUT_DIR/repair_skipped.txt"
else
  for v in "${REPAIR_VERSIONS[@]}"; do
    log "Repair applied: ${v}"
    run_supabase_cli \
      "repair_${v}" \
      "supabase migration repair --status applied ${v} --db-url postgresql://postgres:***@${DB_HOST}:5432/postgres" \
      supabase migration repair --status applied "$v"
  done
fi

log "Step 5/8: migration list"
run_supabase_cli \
  "migration_list_post_repair" \
  "supabase migration list --db-url postgresql://postgres:***@${DB_HOST}:5432/postgres" \
  supabase migration list

log "Step 6/8: db push --dry-run (no apply)"
run_supabase_cli \
  "db_push_dry_run" \
  "supabase db push --dry-run --include-all --db-url postgresql://postgres:***@${DB_HOST}:5432/postgres" \
  supabase db push --dry-run --include-all

verify_dry_run_three_only

log "Step 7/8: post-repair row counts"
collect_row_counts post_repair

log "Step 8/8: compare row counts"
compare_row_counts

log "Phase 2A complete. Artifacts: ${OUT_DIR}"
echo "SUCCESS: migration history repair complete; db push NOT executed."
