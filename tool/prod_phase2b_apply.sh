#!/usr/bin/env bash
# Phase 2B: production migration apply (3 migrations only).
# Does NOT commit, push, deploy, auto-rollback, or delete data.
#
# Usage (password never echoed):
#   ./tool/prod_phase2b_apply.sh
#     dry-run + pre-apply backup + apply gate stop (default)
#
#   APPLY_PHASE2B=yes CONFIRM_PROJECT_REF=vdzzusqisymtejcjnikb ./tool/prod_phase2b_apply.sh
#     apply after all gates pass
#
# Or create tool/db_password.local (gitignored, mode 600, single line).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PG_DUMP="/opt/homebrew/opt/libpq/bin/pg_dump"
PSQL="/opt/homebrew/opt/libpq/bin/psql"
PG_RESTORE="/opt/homebrew/opt/libpq/bin/pg_restore"
PROJECT_REF="${SUPABASE_PROJECT_REF:-vdzzusqisymtejcjnikb}"
REQUIRED_CONFIRM_PROJECT_REF="vdzzusqisymtejcjnikb"

VERIFIED_BACKUP_DIR="${VERIFIED_BACKUP_DIR:-${HOME}/Kalonavi_Backups/20260801T134555Z_pre_workout_met_migration}"

CHECKSUM_FILES=(
  full_backup.dump
  schema_only.sql
  data_only.sql
  backup_metadata.txt
  pre_apply_metrics.txt
)

EXPECTED_MIGRATION_FILES=(
  20260728120000_add_workout_templates_v1.sql
  20260801180000_add_exercise_entry_calculation_columns.sql
  20260801200000_tighten_public_grants_v1.sql
)

EXISTING_ROW_COUNT_TABLES=(
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

RLS_TABLES=(
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
  workout_templates
  workout_template_items
  blocked_food_creators
  food_ratings
  food_rating_stats
  food_reports
  rate_limit_buckets
  alcohol_entries
)

EXERCISE_CALC_COLUMNS=(
  category_key
  activity_id
  intensity
  sets
  reps
  lift_weight_kg
  met_value
  gross_kcal
  net_kcal
  weight_kg_snapshot
  calculation_source
  calculation_version
  source_key
  notes
)

EXERCISE_CALC_INDEXES=(
  exercise_entries_logged_at_user_idx
  exercise_entries_activity_id_idx
)

ANON_SELECT_EXCEPTIONS=(
  saved_foods
  food_rating_stats
)

PERSONAL_TABLES_NO_ANON=(
  users
  profiles
  goals
  nutrition_settings
  health_snapshots
  app_settings
  food_entries
  exercise_entries
  weight_entries
  alcohol_entries
  meal_templates
  meal_template_items
  workout_templates
  workout_template_items
  blocked_food_creators
  food_ratings
  food_reports
  rate_limit_buckets
)

# Hardening migration audited authenticated grants (exact privilege sets).
EXPECTED_AUTH_GRANTS=(
  users:INSERT,SELECT
  profiles:INSERT,SELECT,UPDATE
  goals:INSERT,SELECT,UPDATE
  nutrition_settings:INSERT,SELECT,UPDATE
  health_snapshots:INSERT,SELECT,UPDATE
  app_settings:INSERT,SELECT,UPDATE
  food_entries:DELETE,INSERT,SELECT,UPDATE
  alcohol_entries:DELETE,INSERT,SELECT,UPDATE
  exercise_entries:DELETE,INSERT,SELECT,UPDATE
  weight_entries:DELETE,INSERT,SELECT,UPDATE
  meal_templates:INSERT,SELECT,UPDATE
  meal_template_items:DELETE,INSERT,SELECT,UPDATE
  workout_templates:INSERT,SELECT,UPDATE
  workout_template_items:DELETE,INSERT,SELECT,UPDATE
  blocked_food_creators:DELETE,INSERT,SELECT,UPDATE
  food_ratings:DELETE,INSERT,SELECT,UPDATE
  food_reports:INSERT,SELECT
  saved_foods:INSERT,SELECT,UPDATE
  food_rating_stats:SELECT
  rate_limit_buckets:NONE
)

# Hardening migration audited function EXECUTE (identity signatures).
EXPECTED_ANON_FUNCTION_EXEC=(
  'public.is_saved_food_publicly_visible(text, text, timestamp with time zone, text)'
  'public.is_saved_food_visible_to_viewer(uuid)'
)

EXPECTED_AUTH_FUNCTION_EXEC=(
  'public.is_saved_food_publicly_visible(text, text, timestamp with time zone, text)'
  'public.is_saved_food_visible_to_viewer(uuid)'
  'public.is_saved_food_reportable(text, text, timestamp with time zone)'
  'public.publish_saved_food(text)'
)

cleanup_secrets() {
  unset PGPASSWORD SUPABASE_DB_PASSWORD cli_db_url 2>/dev/null || true
}
trap cleanup_secrets EXIT

if [[ ! -x "$PG_DUMP" || ! -x "$PSQL" || ! -x "$PG_RESTORE" ]]; then
  echo "FAIL: libpq tools not found under /opt/homebrew/opt/libpq/bin" >&2
  exit 1
fi

if [[ -z "${SUPABASE_DB_PASSWORD:-}" && -f "$ROOT/tool/db_password.local" ]]; then
  if ! git -C "$ROOT" check-ignore -q tool/db_password.local; then
    echo "FAIL: tool/db_password.local is not gitignored" >&2
    exit 1
  fi
  pw_mode="$(stat -f '%Lp' "$ROOT/tool/db_password.local" 2>/dev/null || stat -c '%a' "$ROOT/tool/db_password.local")"
  if [[ "$pw_mode" -gt 600 ]]; then
    echo "FAIL: tool/db_password.local permissions must be 600 or stricter (got ${pw_mode})" >&2
    exit 1
  fi
  SUPABASE_DB_PASSWORD="$(<"$ROOT/tool/db_password.local")"
  export SUPABASE_DB_PASSWORD
fi

if [[ -z "${SUPABASE_DB_PASSWORD:-}" ]]; then
  echo "FAIL: SUPABASE_DB_PASSWORD is not set." >&2
  exit 1
fi

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="${HOME}/Kalonavi_Backups/${TS}_phase2b_apply"
BACKUP_DIR="$OUT_DIR/pre_apply_backup"
MIGRATION_SHA_FILE="$OUT_DIR/migration_files_sha256.txt"
mkdir -p "$BACKUP_DIR"
chmod 700 "$OUT_DIR" "$BACKUP_DIR"

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
    echo "working_directory=${ROOT}"
    echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$OUT_DIR/${artifact_name}.meta.txt"
}

run_supabase_cli() {
  local artifact_name="$1"
  local redacted_command="$2"
  shift 2

  write_cli_meta "$artifact_name" "$redacted_command"

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

run_psql_as_role() {
  local role="$1"
  shift
  "$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 -c "SET ROLE ${role}; $* RESET ROLE;"
}

table_exists() {
  run_psql_tsv -c "
select exists (
  select 1 from information_schema.tables
  where table_schema = 'public' and table_name = '${1}'
);"
}

rls_enabled_for_table() {
  run_psql_tsv -c "
select case when c.relrowsecurity then 't' else 'f' end
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname = '${1}';
"
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

authenticated_grants_csv() {
  run_psql_tsv -c "
select coalesce(string_agg(privilege_type, ',' order by privilege_type), 'NONE')
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name = '${1}'
  and grantee = 'authenticated';
"
}

anon_grants_csv() {
  run_psql_tsv -c "
select coalesce(string_agg(privilege_type, ',' order by privilege_type), 'NONE')
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name = '${1}'
  and grantee = 'anon';
"
}

column_exists() {
  run_psql_tsv -c "
select exists (
  select 1 from information_schema.columns
  where table_schema = 'public'
    and table_name = '${1}'
    and column_name = '${2}'
);"
}

index_exists() {
  run_psql_tsv -c "
select exists (
  select 1 from pg_indexes
  where schemaname = 'public'
    and tablename = '${1}'
    and indexname = '${2}'
);"
}

function_execute_signatures_for_role() {
  local role="$1"
  run_psql_tsv -c "
select n.nspname || '.' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')'
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prokind = 'f'
  and has_function_privilege('${role}', p.oid, 'EXECUTE')
order by 1;
"
}

write_migration_file_sha256_to() {
  local dest="$1"
  local label="$2"
  {
    echo "label=${label}"
    echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "working_directory=${ROOT}"
    for f in "${EXPECTED_MIGRATION_FILES[@]}"; do
      local path="$ROOT/supabase/migrations/$f"
      if [[ ! -s "$path" ]]; then
        echo "FAIL: migration file missing or empty: $f" >&2
        return 1
      fi
      echo "${f}=$(shasum -a 256 "$path" | awk '{print $1}')"
    done
  } > "$dest"
}

record_migration_file_sha256() {
  write_migration_file_sha256_to "$MIGRATION_SHA_FILE" "$1"
}

extract_migration_hash_lines() {
  rg '^[0-9]{14}_.*\.sql=' "$1" | sort
}

verify_migration_files_unchanged() {
  local current="$OUT_DIR/migration_files_sha256_recheck.txt"
  write_migration_file_sha256_to "$current" recheck

  local before after
  before="$(extract_migration_hash_lines "$MIGRATION_SHA_FILE")"
  after="$(extract_migration_hash_lines "$current")"

  if [[ "$before" != "$after" ]]; then
    echo "FAIL: migration file SHA-256 changed since dry-run gate" >&2
    {
      echo "=== pre_dry_run migration hashes ==="
      printf '%s\n' "$before"
      echo "=== recheck migration hashes ==="
      printf '%s\n' "$after"
    } > "$OUT_DIR/migration_files_sha256_diff.txt"
    echo "See ${OUT_DIR}/migration_files_sha256_diff.txt" >&2
    return 1
  fi
  log "Migration file SHA-256 unchanged since dry-run gate"
}

verify_verified_backup_readonly() {
  log "Step 1: re-verify prior verified backup (read-only)"
  {
    echo "verified_backup_dir=${VERIFIED_BACKUP_DIR}"
    echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$OUT_DIR/prior_backup_verification.txt"

  for f in full_backup.dump schema_only.sql data_only.sql pre_migration_metrics.txt checksums.sha256; do
    if [[ ! -s "$VERIFIED_BACKUP_DIR/$f" ]]; then
      echo "FAIL: missing prior backup artifact: $f" >&2
      return 1
    fi
    echo "present=$f" >> "$OUT_DIR/prior_backup_verification.txt"
  done

  if ! "$PG_RESTORE" --list "$VERIFIED_BACKUP_DIR/full_backup.dump" \
    >"$OUT_DIR/prior_pg_restore_list.txt" 2>"$OUT_DIR/prior_pg_restore_list.err"; then
    echo "FAIL: prior backup pg_restore --list failed" >&2
    return 1
  fi

  if ! (
    cd "$VERIFIED_BACKUP_DIR"
    shasum -a 256 -c checksums.sha256
  ) >"$OUT_DIR/prior_checksum_verify.txt" 2>&1; then
    echo "FAIL: prior backup checksum verification failed" >&2
    return 1
  fi

  log "Prior verified backup OK"
}

write_pre_apply_metrics() {
  {
    echo "timestamp=${TS}"
    echo "project_ref=${PROJECT_REF}"
    echo "phase=2b_pre_apply"
    echo
    echo "=== row counts (existing tables) ==="
    for t in "${EXISTING_ROW_COUNT_TABLES[@]}"; do
      echo -n "${t}_rows="
      run_psql_tsv -c "SELECT COUNT(*) FROM public.${t};"
    done
  } > "$BACKUP_DIR/pre_apply_metrics.txt"
}

write_backup_metadata() {
  {
    echo "timestamp=${TS}"
    echo "project_ref=${PROJECT_REF}"
    echo "pg_dump_version=$("$PG_DUMP" --version)"
    echo "psql_version=$("$PSQL" --version)"
    echo "cli=prod_phase2b_apply.sh"
    echo "phase=2b_pre_apply_backup"
    echo "target_migrations=${EXPECTED_MIGRATION_FILES[*]}"
  } > "$BACKUP_DIR/backup_metadata.txt"
}

write_checksum_manifest() {
  (
    cd "$BACKUP_DIR"
    shasum -a 256 "${CHECKSUM_FILES[@]}"
  ) > "$BACKUP_DIR/checksums.sha256"
}

verify_new_backup_artifacts() {
  log "Verifying new pre-apply backup artifacts"
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
  if ! "$PG_RESTORE" --list "$BACKUP_DIR/full_backup.dump" \
    >"$BACKUP_DIR/full_backup.list" 2>"$BACKUP_DIR/full_backup.list.err"; then
    echo "FAIL: pg_restore --list failed on new backup" >&2
    return 1
  fi
  if ! (
    cd "$BACKUP_DIR"
    shasum -a 256 -c checksums.sha256
  ) >"$BACKUP_DIR/checksum_verify.txt" 2>&1; then
    echo "FAIL: new backup checksum verification failed" >&2
    return 1
  fi
  if rg -qi 'password' "$BACKUP_DIR/backup_metadata.txt" "$BACKUP_DIR/pre_apply_metrics.txt"; then
    echo "FAIL: password-like string found in backup metadata files" >&2
    return 1
  fi
  log "New pre-apply backup verification OK"
}

take_pre_apply_backup() {
  log "Step 3: new production backup (pre-apply)"
  write_pre_apply_metrics
  "$PG_DUMP" "$DB_URL" --format=custom --file="$BACKUP_DIR/full_backup.dump"
  "$PG_DUMP" "$DB_URL" --schema-only --file="$BACKUP_DIR/schema_only.sql"
  "$PG_DUMP" "$DB_URL" --data-only --file="$BACKUP_DIR/data_only.sql"
  write_backup_metadata
  write_checksum_manifest
  verify_new_backup_artifacts
}

collect_existing_row_counts() {
  local label="$1"
  local file="$OUT_DIR/${label}_existing_row_counts.txt"
  {
    echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "project_ref=${PROJECT_REF}"
    for t in "${EXISTING_ROW_COUNT_TABLES[@]}"; do
      echo "${t}_rows=$(run_psql_tsv -c "SELECT COUNT(*) FROM public.${t};")"
    done
  } > "$file"
}

compare_existing_row_counts() {
  local before="$OUT_DIR/pre_apply_existing_row_counts.txt"
  local after="$OUT_DIR/post_apply_existing_row_counts.txt"
  local cmp="$OUT_DIR/existing_row_count_comparison.txt"
  {
    echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "=== pre_apply ==="
    cat "$before"
    echo "=== post_apply ==="
    cat "$after"
    echo "=== diff ==="
    for t in "${EXISTING_ROW_COUNT_TABLES[@]}"; do
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
    echo "FAIL: existing table row count mismatch after apply" >&2
    echo "See ${cmp}" >&2
    return 1
  fi
  log "Existing table row counts unchanged after apply"
}

verify_dry_run_three_only() {
  local txt_file="$OUT_DIR/db_push_dry_run.txt"
  local err_file="$OUT_DIR/db_push_dry_run.err"
  local migration_pattern='[0-9]{14}_[A-Za-z0-9_]+\.sql'
  local found expected found_count

  found="$(
    {
      [[ -f "$txt_file" ]] && cat "$txt_file"
      [[ -f "$err_file" ]] && cat "$err_file"
    } | rg -o "$migration_pattern" | sort -u
  )"

  expected="$(printf '%s\n' "${EXPECTED_MIGRATION_FILES[@]}" | sort)"
  found_count="$(printf '%s\n' "$found" | sed '/^$/d' | wc -l | tr -d ' ')"

  {
    echo "expected_files:"
    printf '%s\n' "${EXPECTED_MIGRATION_FILES[@]}"
    echo "found_files:"
    printf '%s\n' "$found"
    echo "found_count=${found_count}"
    echo "sources:"
    echo "  ${txt_file}"
    echo "  ${err_file}"
  } > "$OUT_DIR/dry_run_migration_check.txt"

  if [[ "$found_count" -ne 3 ]]; then
    echo "FAIL: dry-run migration count is ${found_count}, expected exactly 3" >&2
    return 1
  fi
  if [[ "$(printf '%s\n' "$found" | sed '/^$/d' | sort)" != "$expected" ]]; then
    echo "FAIL: dry-run migrations do not match expected 3 files exactly" >&2
    return 1
  fi
  log "dry-run shows exactly 3 pending migrations"
}

apply_gate_allows_push() {
  [[ "${APPLY_PHASE2B:-}" == "yes" && "${CONFIRM_PROJECT_REF:-}" == "$REQUIRED_CONFIRM_PROJECT_REF" ]]
}

verify_workout_templates_post_apply() {
  local file="$OUT_DIR/post_apply_workout_templates.txt"
  {
    echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "workout_templates_exists=$(table_exists workout_templates)"
    echo "workout_template_items_exists=$(table_exists workout_template_items)"
    echo "workout_templates_rls=$(rls_enabled_for_table workout_templates)"
    echo "workout_template_items_rls=$(rls_enabled_for_table workout_template_items)"
    echo "workout_templates_policies=$(policy_names_for_table workout_templates)"
    echo "workout_template_items_policies=$(policy_names_for_table workout_template_items)"
    echo "workout_templates_grants=$(grants_for_table workout_templates)"
    echo "workout_template_items_grants=$(grants_for_table workout_template_items)"
  } > "$file"

  if [[ "$(table_exists workout_templates)" != "t" ]]; then
    echo "FAIL: workout_templates table missing" >&2
    return 1
  fi
  if [[ "$(table_exists workout_template_items)" != "t" ]]; then
    echo "FAIL: workout_template_items table missing" >&2
    return 1
  fi
  if [[ "$(rls_enabled_for_table workout_templates)" != "t" || "$(rls_enabled_for_table workout_template_items)" != "t" ]]; then
    echo "FAIL: workout template RLS not enabled" >&2
    return 1
  fi
  if ! rg -q 'workout_templates_own' "$file" || ! rg -q 'workout_template_items_own' "$file"; then
    echo "FAIL: workout template policies missing" >&2
    return 1
  fi
  log "workout_templates / workout_template_items verification OK"
}

verify_exercise_calc_columns_post_apply() {
  local file="$OUT_DIR/post_apply_exercise_calc.txt"
  {
    echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    for col in "${EXERCISE_CALC_COLUMNS[@]}"; do
      echo "${col}_exists=$(column_exists exercise_entries "$col")"
    done
    for idx in "${EXERCISE_CALC_INDEXES[@]}"; do
      echo "${idx}_exists=$(index_exists exercise_entries "$idx")"
    done
  } > "$file"

  for col in "${EXERCISE_CALC_COLUMNS[@]}"; do
    if [[ "$(column_exists exercise_entries "$col")" != "t" ]]; then
      echo "FAIL: exercise_entries column missing: ${col}" >&2
      return 1
    fi
  done
  for idx in "${EXERCISE_CALC_INDEXES[@]}"; do
    if [[ "$(index_exists exercise_entries "$idx")" != "t" ]]; then
      echo "FAIL: exercise_entries index missing: ${idx}" >&2
      return 1
    fi
  done
  log "exercise_entries calculation columns/indexes verification OK"
}

verify_rls_all_tables_post_apply() {
  local file="$OUT_DIR/post_apply_rls_all_tables.txt"
  {
    echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    for t in "${RLS_TABLES[@]}"; do
      echo "${t}_rls=$(rls_enabled_for_table "$t")"
    done
  } > "$file"

  for t in "${RLS_TABLES[@]}"; do
    if [[ "$(rls_enabled_for_table "$t")" != "t" ]]; then
      echo "FAIL: RLS not enabled on ${t}" >&2
      return 1
    fi
  done
  log "RLS enabled on all target public tables"
}

verify_exact_authenticated_grants_post_apply() {
  local file="$OUT_DIR/post_apply_authenticated_grants_exact.txt"
  {
    echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    for entry in "${EXPECTED_AUTH_GRANTS[@]}"; do
      local table="${entry%%:*}"
      local expected="${entry#*:}"
      local actual
      actual="$(authenticated_grants_csv "$table")"
      echo "${table}_expected=${expected}"
      echo "${table}_actual=${actual}"
      if [[ "$actual" != "$expected" ]]; then
        echo "${table}_status=MISMATCH"
      else
        echo "${table}_status=OK"
      fi
    done
  } > "$file"

  for entry in "${EXPECTED_AUTH_GRANTS[@]}"; do
    local table="${entry%%:*}"
    local expected="${entry#*:}"
    local actual
    actual="$(authenticated_grants_csv "$table")"
    if [[ "$actual" != "$expected" ]]; then
      echo "FAIL: authenticated grants mismatch on ${table}: expected=${expected} actual=${actual}" >&2
      return 1
    fi
  done
  log "authenticated table grants match audited matrix"
}

verify_function_execute_post_apply() {
  local file="$OUT_DIR/post_apply_function_execute_exact.txt"
  local anon_found auth_found anon_expected auth_expected

  anon_found="$(function_execute_signatures_for_role anon)"
  auth_found="$(function_execute_signatures_for_role authenticated)"
  anon_expected="$(printf '%s\n' "${EXPECTED_ANON_FUNCTION_EXEC[@]}" | sort)"
  auth_expected="$(printf '%s\n' "${EXPECTED_AUTH_FUNCTION_EXEC[@]}" | sort)"

  {
    echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "=== anon expected ==="
    printf '%s\n' "${EXPECTED_ANON_FUNCTION_EXEC[@]}"
    echo "=== anon actual ==="
    printf '%s\n' "$anon_found"
    echo "=== authenticated expected ==="
    printf '%s\n' "${EXPECTED_AUTH_FUNCTION_EXEC[@]}"
    echo "=== authenticated actual ==="
    printf '%s\n' "$auth_found"
  } > "$file"

  if [[ "$(printf '%s\n' "$anon_found" | sed '/^$/d' | sort)" != "$anon_expected" ]]; then
    echo "FAIL: anon function EXECUTE set mismatch" >&2
    return 1
  fi
  if [[ "$(printf '%s\n' "$auth_found" | sed '/^$/d' | sort)" != "$auth_expected" ]]; then
    echo "FAIL: authenticated function EXECUTE set mismatch" >&2
    return 1
  fi
  log "function EXECUTE grants match audited signatures"
}

verify_hardening_grants_post_apply() {
  local file="$OUT_DIR/post_apply_hardening_grants.txt"
  local anon_bad auth_bad

  anon_bad="$(run_psql_tsv -c "
SELECT COUNT(*)::text
FROM information_schema.role_table_grants
WHERE grantee = 'anon'
  AND table_schema = 'public'
  AND privilege_type IN ('TRUNCATE', 'REFERENCES', 'TRIGGER');
")"

  auth_bad="$(run_psql_tsv -c "
SELECT COUNT(*)::text
FROM information_schema.role_table_grants
WHERE grantee = 'authenticated'
  AND table_schema = 'public'
  AND privilege_type IN ('TRUNCATE', 'REFERENCES', 'TRIGGER');
")"

  {
    echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "anon_truncate_references_trigger_count=${anon_bad}"
    echo "authenticated_truncate_references_trigger_count=${auth_bad}"
    echo
    echo "=== anon grants on personal tables ==="
    for t in "${PERSONAL_TABLES_NO_ANON[@]}"; do
      echo "${t}_anon_grants=$(anon_grants_csv "$t")"
    done
    echo
    echo "=== anon grants on public-read exceptions ==="
    for t in "${ANON_SELECT_EXCEPTIONS[@]}"; do
      echo "${t}_anon_grants=$(anon_grants_csv "$t")"
    done
  } > "$file"

  if [[ "$anon_bad" != "0" || "$auth_bad" != "0" ]]; then
    echo "FAIL: TRUNCATE/REFERENCES/TRIGGER grants still present" >&2
    return 1
  fi

  for t in "${PERSONAL_TABLES_NO_ANON[@]}"; do
    if [[ "$(anon_grants_csv "$t")" != "NONE" ]]; then
      echo "FAIL: anon grants found on personal table: ${t}" >&2
      return 1
    fi
  done

  for t in "${ANON_SELECT_EXCEPTIONS[@]}"; do
    if [[ "$(anon_grants_csv "$t")" != "SELECT" ]]; then
      echo "FAIL: expected anon SELECT only on ${t}, got: $(anon_grants_csv "$t")" >&2
      return 1
    fi
  done

  log "dangerous grants absent; anon personal-table policy OK"
}

verify_blocked_food_creators_anon_isolation_post_apply() {
  local file="$OUT_DIR/post_apply_blocked_food_creators_anon.txt"
  local anon_grants probe_exit=0 probe_msg

  anon_grants="$(anon_grants_csv blocked_food_creators)"
  set +e
  probe_msg="$(run_psql_as_role anon "SELECT COUNT(*) FROM public.blocked_food_creators;" 2>&1)"
  probe_exit=$?
  set -e

  {
    echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "blocked_food_creators_anon_grants=${anon_grants}"
    echo "anon_select_probe_exit=${probe_exit}"
    echo "anon_select_probe_message=${probe_msg}"
  } > "$file"

  if [[ "$anon_grants" != "NONE" ]]; then
    echo "FAIL: blocked_food_creators must have no anon grants" >&2
    return 1
  fi
  if [[ "$probe_exit" -eq 0 ]]; then
    echo "FAIL: anon must not read blocked_food_creators (expected permission denied)" >&2
    return 1
  fi
  log "blocked_food_creators anon isolation OK (no grant, SELECT denied)"
}

verify_migration_list_post_apply() {
  local list_file="$OUT_DIR/migration_list_post_apply.txt"
  local check_file="$OUT_DIR/migration_list_post_apply_check.txt"
  local pending_count=0

  {
    echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    for f in "${EXPECTED_MIGRATION_FILES[@]}"; do
      local ts="${f%%_*}"
      local line remote_col
      line="$(rg "${ts}" "$list_file" || true)"
      echo "migration=${f}"
      echo "line=${line}"
      if [[ -z "$line" ]]; then
        echo "status=MISSING"
        pending_count=$((pending_count + 1))
        continue
      fi
      remote_col="$(printf '%s\n' "$line" | rg -o '\|\s*`[^`]*`\s*\|' | tail -1 | tr -d '|`' | xargs || true)"
      if [[ -z "$remote_col" || "$remote_col" != "$ts" ]]; then
        echo "status=NOT_APPLIED remote=${remote_col:-empty}"
        pending_count=$((pending_count + 1))
      else
        echo "status=APPLIED"
      fi
    done
    echo "pending_target_migrations=${pending_count}"
  } > "$check_file"

  if [[ "$pending_count" -ne 0 ]]; then
    echo "FAIL: expected 3 target migrations Remote applied, pending=${pending_count}" >&2
    return 1
  fi

  run_supabase_cli \
    "db_push_dry_run_post_apply" \
    "supabase db push --dry-run --include-all --db-url postgresql://postgres:***@${DB_HOST}:5432/postgres" \
    supabase db push --dry-run --include-all

  local post_found_count
  post_found_count="$(
    {
      cat "$OUT_DIR/db_push_dry_run_post_apply.txt"
      cat "$OUT_DIR/db_push_dry_run_post_apply.err"
    } | { rg -o '[0-9]{14}_[A-Za-z0-9_]+\.sql' 2>/dev/null || true; } | sort -u | sed '/^$/d' | wc -l | tr -d ' '
  )"
  post_found_count="${post_found_count:-0}"
  echo "post_apply_pending_migration_files=${post_found_count}" >> "$check_file"
  if [[ "$post_found_count" -ne 0 ]]; then
    echo "FAIL: post-apply dry-run still lists ${post_found_count} pending migration file(s)" >&2
    return 1
  fi
  log "migration list post-apply OK; pending migrations 0"
}

{
  echo "phase=2b_apply"
  echo "project_ref=${PROJECT_REF}"
  echo "working_directory=${ROOT}"
  echo "verified_backup_dir=${VERIFIED_BACKUP_DIR}"
  echo "output_dir=${OUT_DIR}"
  echo "pre_apply_backup_dir=${BACKUP_DIR}"
  echo "target_migrations=${EXPECTED_MIGRATION_FILES[*]}"
  echo "apply_phase2b=${APPLY_PHASE2B:-}"
  echo "confirm_project_ref=${CONFIRM_PROJECT_REF:-}"
} > "$OUT_DIR/phase2b_metadata.txt"

log "Phase 2B output dir: ${OUT_DIR}"
log "Working directory: ${ROOT}"
log "Verified backup dir: ${VERIFIED_BACKUP_DIR}"

verify_verified_backup_readonly

log "Step 2: DB auth probe"
if ! run_psql_tsv -c "SELECT 1;" >/dev/null 2>"$OUT_DIR/auth_probe.err"; then
  echo "FAIL: DB authentication failed" >&2
  exit 1
fi
log "DB auth OK"

take_pre_apply_backup

log "Step 4: pre-apply existing table row counts"
collect_existing_row_counts pre_apply

log "Step 5: record migration file SHA-256 (pre dry-run)"
record_migration_file_sha256 pre_dry_run

log "Step 6: supabase migration list (pre-apply)"
run_supabase_cli \
  "migration_list_pre_apply" \
  "supabase migration list --db-url postgresql://postgres:***@${DB_HOST}:5432/postgres" \
  supabase migration list

log "Step 7: db push --dry-run --include-all (no apply)"
run_supabase_cli \
  "db_push_dry_run" \
  "supabase db push --dry-run --include-all --db-url postgresql://postgres:***@${DB_HOST}:5432/postgres" \
  supabase db push --dry-run --include-all

verify_dry_run_three_only

log "Step 8: apply gate (dual confirmation)"
if ! apply_gate_allows_push; then
  log "STOP: apply gate not satisfied. Production migrations were NOT applied."
  {
    echo "applied=false"
    echo "apply_phase2b=${APPLY_PHASE2B:-}"
    echo "confirm_project_ref=${CONFIRM_PROJECT_REF:-}"
    echo "required_confirm_project_ref=${REQUIRED_CONFIRM_PROJECT_REF}"
    echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "to_apply=APPLY_PHASE2B=yes CONFIRM_PROJECT_REF=${REQUIRED_CONFIRM_PROJECT_REF} ./tool/prod_phase2b_apply.sh"
  } > "$OUT_DIR/apply_gate_stopped.txt"
  log "Dry-run and pre-apply backup complete. Artifacts: ${OUT_DIR}"
  exit 0
fi

log "Step 9: re-verify migration file SHA-256 (pre apply)"
verify_migration_files_unchanged

log "Step 10: db push --include-all (single apply)"
run_supabase_cli \
  "db_push_apply" \
  "supabase db push --include-all --db-url postgresql://postgres:***@${DB_HOST}:5432/postgres" \
  supabase db push --include-all

log "Step 11: migration list (post-apply)"
run_supabase_cli \
  "migration_list_post_apply" \
  "supabase migration list --db-url postgresql://postgres:***@${DB_HOST}:5432/postgres" \
  supabase migration list

verify_migration_list_post_apply

log "Step 12: post-apply existing table row counts"
collect_existing_row_counts post_apply

log "Step 13: compare existing table row counts"
compare_existing_row_counts

log "Step 14: verify workout_templates"
verify_workout_templates_post_apply

log "Step 15: verify exercise_entries calculation columns"
verify_exercise_calc_columns_post_apply

log "Step 16: verify RLS on all target tables"
verify_rls_all_tables_post_apply

log "Step 17: verify exact authenticated grants"
verify_exact_authenticated_grants_post_apply

log "Step 18: verify exact function EXECUTE grants"
verify_function_execute_post_apply

log "Step 19: verify hardening grant policy"
verify_hardening_grants_post_apply

log "Step 20: verify blocked_food_creators anon isolation"
verify_blocked_food_creators_anon_isolation_post_apply

log "Phase 2B complete. Artifacts: ${OUT_DIR}"
echo "SUCCESS: production migrations applied; git commit/push/deploy NOT performed."
