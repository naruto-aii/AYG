#!/usr/bin/env bash
# Phase 2B verify-only: read-only post-apply checks (Steps 12–20 + migration sync).
# Does NOT apply migrations, repair history, reset, backup, commit, or deploy.
#
# Allowed production DB operations:
#   - SELECT (postgres role)
#   - supabase migration list
#   - supabase db push --dry-run --include-all
#
# Usage (password never echoed):
#   ./tool/prod_phase2b_verify_only.sh
#
#   VERIFY_ONLY_BOOT_TEST=yes ./tool/prod_phase2b_verify_only.sh
#     boot test: stops after init/static audit, before DB connection
#
# Or create tool/db_password.local (gitignored, mode 600, single line).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PSQL="/opt/homebrew/opt/libpq/bin/psql"
PROJECT_REF="vdzzusqisymtejcjnikb"

PRE_APPLY_ROW_COUNTS="${PRE_APPLY_ROW_COUNTS:-${HOME}/Kalonavi_Backups/20260802T111049Z_phase2b_apply/pre_apply_existing_row_counts.txt}"

ALL_MIGRATION_TIMESTAMPS=(
  20260722130000
  20260723120000
  20260727120000
  20260728120000
  20260729120000
  20260801120000
  20260801180000
  20260801200000
)

PHASE2B_MIGRATION_FILES=(
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

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="${HOME}/Kalonavi_Backups/${TS}_phase2b_verify"
SUMMARY_FILE="$OUT_DIR/verification_summary.txt"
FAIL_COUNT=0

cleanup_secrets() {
  unset PGPASSWORD SUPABASE_DB_PASSWORD cli_db_url 2>/dev/null || true
}
trap cleanup_secrets EXIT

log() { echo "[$(date -u +%H:%M:%S)] $*"; }

record_result() {
  local name="$1"
  local status="$2"
  local detail="${3:-}"
  echo "${status} ${name}${detail:+: ${detail}}" >> "$SUMMARY_FILE"
  if [[ "$status" == "FAIL" ]]; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "FAIL: ${name}${detail:+ — ${detail}}" >&2
  else
    log "PASS: ${name}${detail:+ — ${detail}}"
  fi
}

count_pending_migration_files() {
  local txt_file="$1"
  local err_file="$2"
  local count
  count="$(
    {
      [[ -f "$txt_file" ]] && cat "$txt_file"
      [[ -f "$err_file" ]] && cat "$err_file"
    } | { rg -o '[0-9]{14}_[A-Za-z0-9_]+\.sql' 2>/dev/null || true; } | sort -u | sed '/^$/d' | wc -l | tr -d ' '
  )"
  echo "${count:-0}"
}

static_safety_audit() {
  local script_path="$ROOT/tool/prod_phase2b_verify_only.sh"
  local line hit

  log "Static safety audit (no DB connection)"
  {
    echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "script=${script_path}"
    echo "mode=read_only_static_audit"
  } > "$OUT_DIR/static_safety_audit.txt"

  if rg -q 'db push' "$script_path" && ! rg -q 'db push --dry-run' "$script_path"; then
    echo "FAIL forbidden: db push without --dry-run" >> "$OUT_DIR/static_safety_audit.txt"
    record_result "static_safety_audit" "FAIL" "db push without --dry-run referenced"
    return 1
  fi

  if rg -q 'supabase (migration repair|db reset)' "$script_path"; then
    echo "FAIL forbidden: migration repair or db reset" >> "$OUT_DIR/static_safety_audit.txt"
    record_result "static_safety_audit" "FAIL" "repair/reset referenced"
    return 1
  fi

  if rg -n 'run_psql_tsv -c|run_psql_as_role' "$script_path" \
    | rg -v 'static_safety_audit|mutating SQL|run_psql_tsv\(\)|run_psql_as_role\(\)' \
    | rg -qi 'insert|update|delete|truncate|grant|revoke|create |alter |drop '; then
    echo "FAIL forbidden: mutating SQL in psql helpers" >> "$OUT_DIR/static_safety_audit.txt"
    record_result "static_safety_audit" "FAIL" "mutating SQL pattern in psql calls"
    return 1
  fi

  while IFS= read -r line; do
    if printf '%s\n' "$line" | rg -q 'db push --dry-run'; then
      continue
    fi
    if printf '%s\n' "$line" | rg -qi 'db push --include-all|migration repair|db reset'; then
      echo "FAIL forbidden token on script line: ${line}" >> "$OUT_DIR/static_safety_audit.txt"
      record_result "static_safety_audit" "FAIL" "forbidden apply/repair/reset token"
      return 1
    fi
  done < <(rg -n 'supabase ' "$script_path" | rg -v 'static_safety_audit|if rg|done < <\(rg|^\s*#' || true)

  echo "PASS no forbidden write/apply patterns detected" >> "$OUT_DIR/static_safety_audit.txt"
  record_result "static_safety_audit" "PASS"
}

if [[ ! -x "$PSQL" ]]; then
  echo "FAIL: psql not found under /opt/homebrew/opt/libpq/bin" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
chmod 700 "$OUT_DIR"

{
  echo "phase=2b_verify_only"
  echo "project_ref=${PROJECT_REF}"
  echo "working_directory=${ROOT}"
  echo "output_dir=${OUT_DIR}"
  echo "pre_apply_row_counts=${PRE_APPLY_ROW_COUNTS}"
  echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$OUT_DIR/phase2b_verify_metadata.txt"

: > "$SUMMARY_FILE"

static_safety_audit || true

if [[ "$PROJECT_REF" != "vdzzusqisymtejcjnikb" ]]; then
  record_result "project_ref_fixed" "FAIL" "unexpected PROJECT_REF=${PROJECT_REF}"
  echo "Overall: FAIL (${FAIL_COUNT} check(s) failed). Artifacts: ${OUT_DIR}" >&2
  exit 1
fi
record_result "project_ref_fixed" "PASS" "vdzzusqisymtejcjnikb"

if [[ ! -s "$PRE_APPLY_ROW_COUNTS" ]]; then
  record_result "pre_apply_row_counts_baseline" "FAIL" "missing ${PRE_APPLY_ROW_COUNTS}"
  echo "Overall: FAIL (${FAIL_COUNT} check(s) failed). Artifacts: ${OUT_DIR}" >&2
  exit 1
fi
record_result "pre_apply_row_counts_baseline" "PASS" "$PRE_APPLY_ROW_COUNTS"

if [[ "${VERIFY_ONLY_BOOT_TEST:-}" == "yes" ]]; then
  record_result "boot_test_stop_before_db" "PASS" "no DB connection attempted"
  {
    echo "overall=BOOT_TEST_PASS"
    echo "fail_count=${FAIL_COUNT}"
    echo "output_dir=${OUT_DIR}"
    echo "stopped_before=db_password_load"
  } >> "$SUMMARY_FILE"
  log "Boot test OK: stopped before DB connection. Artifacts: ${OUT_DIR}"
  echo "BOOT TEST OK: stopped before DB connection. Artifacts: ${OUT_DIR}"
  exit 0
fi

if [[ -z "${SUPABASE_DB_PASSWORD:-}" && -f "$ROOT/tool/db_password.local" ]]; then
  if ! git -C "$ROOT" check-ignore -q tool/db_password.local; then
    record_result "db_auth" "FAIL" "tool/db_password.local is not gitignored"
    echo "Overall: FAIL (${FAIL_COUNT} check(s) failed). Artifacts: ${OUT_DIR}" >&2
    exit 1
  fi
  pw_mode="$(stat -f '%Lp' "$ROOT/tool/db_password.local" 2>/dev/null || stat -c '%a' "$ROOT/tool/db_password.local")"
  if [[ "$pw_mode" -gt 600 ]]; then
    record_result "db_auth" "FAIL" "db_password.local permissions ${pw_mode}"
    echo "Overall: FAIL (${FAIL_COUNT} check(s) failed). Artifacts: ${OUT_DIR}" >&2
    exit 1
  fi
  SUPABASE_DB_PASSWORD="$(<"$ROOT/tool/db_password.local")"
  export SUPABASE_DB_PASSWORD
fi

if [[ -z "${SUPABASE_DB_PASSWORD:-}" ]]; then
  record_result "db_auth" "FAIL" "SUPABASE_DB_PASSWORD is not set"
  echo "Overall: FAIL (${FAIL_COUNT} check(s) failed). Artifacts: ${OUT_DIR}" >&2
  exit 1
fi

DB_HOST="db.${PROJECT_REF}.supabase.co"
DB_URL="postgresql://postgres@${DB_HOST}:5432/postgres"
export PGPASSWORD="$SUPABASE_DB_PASSWORD"

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
  local exit_code="$3"
  {
    echo "supabase_version=$(supabase --version 2>/dev/null || echo unknown)"
    echo "command=${redacted_command}"
    echo "working_directory=${ROOT}"
    echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "exit_code=${exit_code}"
  } > "$OUT_DIR/${artifact_name}.meta.txt"
}

run_supabase_cli() {
  local artifact_name="$1"
  local redacted_command="$2"
  shift 2

  cli_db_url="$(build_supabase_cli_db_url)"
  set +e
  "$@" --db-url "$cli_db_url" \
    >"$OUT_DIR/${artifact_name}.txt" \
    2>"$OUT_DIR/${artifact_name}.err"
  local exit_code=$?
  set -e
  unset cli_db_url

  write_cli_meta "$artifact_name" "$redacted_command" "$exit_code"

  if [[ "$exit_code" -ne 0 ]]; then
    record_result "${artifact_name}" "FAIL" "exit ${exit_code}"
    return "$exit_code"
  fi
  record_result "${artifact_name}" "PASS"
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
select n.nspname || '.' || p.proname || '(' || pg_catalog.oidvectortypes(p.proargtypes) || ')'
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prokind = 'f'
  and has_function_privilege('${role}', p.oid, 'EXECUTE')
order by 1;
"
}

log "Phase 2B verify-only output dir: ${OUT_DIR}"

log "Step V1: DB auth probe (SELECT 1)"
if ! run_psql_tsv -c "SELECT 1;" >/dev/null 2>"$OUT_DIR/auth_probe.err"; then
  record_result "db_auth_probe" "FAIL" "authentication failed; no retry"
  {
    echo "overall=FAIL"
    echo "fail_count=${FAIL_COUNT}"
    echo "output_dir=${OUT_DIR}"
  } >> "$SUMMARY_FILE"
  echo "Overall: FAIL (${FAIL_COUNT} check(s) failed). Artifacts: ${OUT_DIR}" >&2
  exit 1
fi
record_result "db_auth_probe" "PASS"

log "Step V2: supabase migration list"
if ! run_supabase_cli \
  "migration_list_verify" \
  "supabase migration list --db-url postgresql://postgres:***@${DB_HOST}:5432/postgres" \
  supabase migration list; then
  {
    echo "overall=FAIL"
    echo "fail_count=${FAIL_COUNT}"
    echo "output_dir=${OUT_DIR}"
  } >> "$SUMMARY_FILE"
  echo "Overall: FAIL (${FAIL_COUNT} check(s) failed). Artifacts: ${OUT_DIR}" >&2
  exit 1
fi

log "Step V3: verify 8 migrations Local/Remote match"
{
  echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "expected_migration_count=8"
} > "$OUT_DIR/migration_sync_check.txt"

migration_sync_ok=true
for ts in "${ALL_MIGRATION_TIMESTAMPS[@]}"; do
  line="$(rg "${ts}" "$OUT_DIR/migration_list_verify.txt" || true)"
  local_col=""
  remote_col=""
  echo "migration=${ts}" >> "$OUT_DIR/migration_sync_check.txt"
  echo "line=${line}" >> "$OUT_DIR/migration_sync_check.txt"
  if [[ -z "$line" ]]; then
    echo "status=MISSING" >> "$OUT_DIR/migration_sync_check.txt"
    migration_sync_ok=false
    continue
  fi
  local_col="$(printf '%s\n' "$line" | rg -o '\|\s*`[^`]*`\s*\|' | head -1 | tr -d ' |`' || true)"
  remote_col="$(printf '%s\n' "$line" | rg -o '\|\s*`[^`]*`\s*\|' | tail -1 | tr -d ' |`' || true)"
  echo "local=${local_col} remote=${remote_col}" >> "$OUT_DIR/migration_sync_check.txt"
  if [[ -z "$local_col" || -z "$remote_col" || "$local_col" != "$ts" || "$remote_col" != "$ts" ]]; then
    echo "status=MISMATCH" >> "$OUT_DIR/migration_sync_check.txt"
    migration_sync_ok=false
  else
    echo "status=SYNCED" >> "$OUT_DIR/migration_sync_check.txt"
  fi
done

if [[ "$migration_sync_ok" == true ]]; then
  record_result "migration_local_remote_sync_8" "PASS"
else
  record_result "migration_local_remote_sync_8" "FAIL" "see migration_sync_check.txt"
fi

log "Step V4: verify Phase 2B target migrations applied"
{
  echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$OUT_DIR/phase2b_target_migration_check.txt"
phase2b_target_ok=true
for f in "${PHASE2B_MIGRATION_FILES[@]}"; do
  ts="${f%%_*}"
  line="$(rg "${ts}" "$OUT_DIR/migration_list_verify.txt" || true)"
  remote_col="$(printf '%s\n' "$line" | rg -o '\|\s*`[^`]*`\s*\|' | tail -1 | tr -d ' |`' || true)"
  echo "migration=${f}" >> "$OUT_DIR/phase2b_target_migration_check.txt"
  echo "remote=${remote_col:-empty}" >> "$OUT_DIR/phase2b_target_migration_check.txt"
  if [[ -z "$remote_col" || "$remote_col" != "$ts" ]]; then
    echo "status=NOT_APPLIED" >> "$OUT_DIR/phase2b_target_migration_check.txt"
    phase2b_target_ok=false
  else
    echo "status=APPLIED" >> "$OUT_DIR/phase2b_target_migration_check.txt"
  fi
done

if [[ "$phase2b_target_ok" == true ]]; then
  record_result "phase2b_target_migrations_applied" "PASS"
else
  record_result "phase2b_target_migrations_applied" "FAIL"
fi

log "Step V5: db push --dry-run --include-all (pending must be 0)"
if ! run_supabase_cli \
  "db_push_dry_run_verify" \
  "supabase db push --dry-run --include-all --db-url postgresql://postgres:***@${DB_HOST}:5432/postgres" \
  supabase db push --dry-run --include-all; then
  {
    echo "overall=FAIL"
    echo "fail_count=${FAIL_COUNT}"
    echo "output_dir=${OUT_DIR}"
  } >> "$SUMMARY_FILE"
  echo "Overall: FAIL (${FAIL_COUNT} check(s) failed). Artifacts: ${OUT_DIR}" >&2
  exit 1
fi

pending_count="$(count_pending_migration_files "$OUT_DIR/db_push_dry_run_verify.txt" "$OUT_DIR/db_push_dry_run_verify.err")"
echo "pending_migration_files=${pending_count}" >> "$OUT_DIR/db_push_dry_run_verify.meta.txt"
if [[ "$pending_count" -eq 0 ]]; then
  record_result "pending_migrations_zero" "PASS"
else
  record_result "pending_migrations_zero" "FAIL" "pending=${pending_count}"
fi

log "Step V6: post-apply existing table row counts"
{
  echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "project_ref=${PROJECT_REF}"
  for t in "${EXISTING_ROW_COUNT_TABLES[@]}"; do
    echo "${t}_rows=$(run_psql_tsv -c "SELECT COUNT(*) FROM public.${t};")"
  done
} > "$OUT_DIR/post_apply_existing_row_counts.txt"
record_result "post_apply_row_counts_collected" "PASS"

log "Step V7: compare row counts (must not decrease vs pre-apply baseline)"
{
  echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "baseline=${PRE_APPLY_ROW_COUNTS}"
  echo "=== baseline ==="
  cat "$PRE_APPLY_ROW_COUNTS"
  echo "=== current ==="
  cat "$OUT_DIR/post_apply_existing_row_counts.txt"
  echo "=== comparison ==="
} > "$OUT_DIR/existing_row_count_comparison.txt"

row_compare_ok=true
for t in "${EXISTING_ROW_COUNT_TABLES[@]}"; do
  b="$(rg "^${t}_rows=" "$PRE_APPLY_ROW_COUNTS" | cut -d= -f2)"
  a="$(rg "^${t}_rows=" "$OUT_DIR/post_apply_existing_row_counts.txt" | cut -d= -f2)"
  if [[ -z "$b" || -z "$a" ]]; then
    echo "FAIL ${t}: missing baseline or current count" >> "$OUT_DIR/existing_row_count_comparison.txt"
    row_compare_ok=false
  elif [[ "$a" -lt "$b" ]]; then
    echo "FAIL ${t}: decreased pre=${b} post=${a}" >> "$OUT_DIR/existing_row_count_comparison.txt"
    row_compare_ok=false
  else
    echo "OK ${t}: pre=${b} post=${a}" >> "$OUT_DIR/existing_row_count_comparison.txt"
  fi
done

if [[ "$row_compare_ok" == true ]]; then
  record_result "existing_row_counts_not_decreased" "PASS"
else
  record_result "existing_row_counts_not_decreased" "FAIL" "see existing_row_count_comparison.txt"
fi

log "Step V8: workout template tables + initial row counts"
{
  echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "workout_templates_exists=$(table_exists workout_templates)"
  echo "workout_template_items_exists=$(table_exists workout_template_items)"
  echo "workout_templates_rows=$(run_psql_tsv -c "SELECT COUNT(*) FROM public.workout_templates;")"
  echo "workout_template_items_rows=$(run_psql_tsv -c "SELECT COUNT(*) FROM public.workout_template_items;")"
  echo "workout_templates_rls=$(rls_enabled_for_table workout_templates)"
  echo "workout_template_items_rls=$(rls_enabled_for_table workout_template_items)"
  echo "workout_templates_policies=$(policy_names_for_table workout_templates)"
  echo "workout_template_items_policies=$(policy_names_for_table workout_template_items)"
} > "$OUT_DIR/post_apply_workout_templates.txt"

workout_ok=true
if [[ "$(table_exists workout_templates)" != "t" ]]; then workout_ok=false; fi
if [[ "$(table_exists workout_template_items)" != "t" ]]; then workout_ok=false; fi
if [[ "$(rls_enabled_for_table workout_templates)" != "t" ]]; then workout_ok=false; fi
if [[ "$(rls_enabled_for_table workout_template_items)" != "t" ]]; then workout_ok=false; fi
if ! rg -q 'workout_templates_own' "$OUT_DIR/post_apply_workout_templates.txt"; then workout_ok=false; fi
if ! rg -q 'workout_template_items_own' "$OUT_DIR/post_apply_workout_templates.txt"; then workout_ok=false; fi

if [[ "$workout_ok" == true ]]; then
  record_result "workout_templates_schema" "PASS"
else
  record_result "workout_templates_schema" "FAIL" "see post_apply_workout_templates.txt"
fi

log "Step V9: exercise_entries calculation columns and indexes"
{
  echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  for col in "${EXERCISE_CALC_COLUMNS[@]}"; do
    echo "${col}_exists=$(column_exists exercise_entries "$col")"
  done
  for idx in "${EXERCISE_CALC_INDEXES[@]}"; do
    echo "${idx}_exists=$(index_exists exercise_entries "$idx")"
  done
} > "$OUT_DIR/post_apply_exercise_calc.txt"

exercise_ok=true
for col in "${EXERCISE_CALC_COLUMNS[@]}"; do
  if [[ "$(column_exists exercise_entries "$col")" != "t" ]]; then exercise_ok=false; fi
done
for idx in "${EXERCISE_CALC_INDEXES[@]}"; do
  if [[ "$(index_exists exercise_entries "$idx")" != "t" ]]; then exercise_ok=false; fi
done

if [[ "$exercise_ok" == true ]]; then
  record_result "exercise_calc_columns_indexes" "PASS"
else
  record_result "exercise_calc_columns_indexes" "FAIL" "see post_apply_exercise_calc.txt"
fi

log "Step V10: RLS on all target tables"
{
  echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  for t in "${RLS_TABLES[@]}"; do
    echo "${t}_rls=$(rls_enabled_for_table "$t")"
  done
} > "$OUT_DIR/post_apply_rls_all_tables.txt"

rls_ok=true
for t in "${RLS_TABLES[@]}"; do
  if [[ "$(rls_enabled_for_table "$t")" != "t" ]]; then rls_ok=false; fi
done

if [[ "$rls_ok" == true ]]; then
  record_result "rls_all_target_tables" "PASS"
else
  record_result "rls_all_target_tables" "FAIL" "see post_apply_rls_all_tables.txt"
fi

log "Step V11: authenticated grants exact match"
{
  echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  for entry in "${EXPECTED_AUTH_GRANTS[@]}"; do
    table="${entry%%:*}"
    expected="${entry#*:}"
    actual="$(authenticated_grants_csv "$table")"
    echo "${table}_expected=${expected}"
    echo "${table}_actual=${actual}"
    if [[ "$actual" == "$expected" ]]; then
      echo "${table}_status=OK"
    else
      echo "${table}_status=MISMATCH"
    fi
  done
} > "$OUT_DIR/post_apply_authenticated_grants_exact.txt"

auth_grants_ok=true
for entry in "${EXPECTED_AUTH_GRANTS[@]}"; do
  table="${entry%%:*}"
  expected="${entry#*:}"
  actual="$(authenticated_grants_csv "$table")"
  if [[ "$actual" != "$expected" ]]; then auth_grants_ok=false; fi
done

if [[ "$auth_grants_ok" == true ]]; then
  record_result "authenticated_grants_exact" "PASS"
else
  record_result "authenticated_grants_exact" "FAIL" "see post_apply_authenticated_grants_exact.txt"
fi

log "Step V12: dangerous table grants + anon policy"
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
} > "$OUT_DIR/post_apply_hardening_grants.txt"

hardening_ok=true
if [[ "$anon_bad" != "0" || "$auth_bad" != "0" ]]; then hardening_ok=false; fi
for t in "${PERSONAL_TABLES_NO_ANON[@]}"; do
  if [[ "$(anon_grants_csv "$t")" != "NONE" ]]; then hardening_ok=false; fi
done
for t in "${ANON_SELECT_EXCEPTIONS[@]}"; do
  if [[ "$(anon_grants_csv "$t")" != "SELECT" ]]; then hardening_ok=false; fi
done

if [[ "$hardening_ok" == true ]]; then
  record_result "hardening_grants_and_anon_policy" "PASS"
else
  record_result "hardening_grants_and_anon_policy" "FAIL" "see post_apply_hardening_grants.txt"
fi

log "Step V13: function EXECUTE grants"
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
} > "$OUT_DIR/post_apply_function_execute_exact.txt"

func_ok=true
if [[ "$(printf '%s\n' "$anon_found" | sed '/^$/d' | sort)" != "$anon_expected" ]]; then func_ok=false; fi
if [[ "$(printf '%s\n' "$auth_found" | sed '/^$/d' | sort)" != "$auth_expected" ]]; then func_ok=false; fi

if [[ "$func_ok" == true ]]; then
  record_result "function_execute_grants_exact" "PASS"
else
  record_result "function_execute_grants_exact" "FAIL" "see post_apply_function_execute_exact.txt"
fi

log "Step V14: blocked_food_creators anon isolation"
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
} > "$OUT_DIR/post_apply_blocked_food_creators_anon.txt"

blocked_ok=true
if [[ "$anon_grants" != "NONE" ]]; then blocked_ok=false; fi
if [[ "$probe_exit" -eq 0 ]]; then blocked_ok=false; fi

if [[ "$blocked_ok" == true ]]; then
  record_result "blocked_food_creators_anon_isolation" "PASS"
else
  record_result "blocked_food_creators_anon_isolation" "FAIL" "see post_apply_blocked_food_creators_anon.txt"
fi

if [[ "$FAIL_COUNT" -eq 0 ]]; then
  {
    echo "overall=PASS"
    echo "fail_count=0"
    echo "output_dir=${OUT_DIR}"
  } >> "$SUMMARY_FILE"
  log "Phase 2B verify-only complete. All checks PASS. Artifacts: ${OUT_DIR}"
  echo "SUCCESS: Phase 2B verify-only PASS. Artifacts: ${OUT_DIR}"
  exit 0
fi

{
  echo "overall=FAIL"
  echo "fail_count=${FAIL_COUNT}"
  echo "output_dir=${OUT_DIR}"
} >> "$SUMMARY_FILE"
echo "Overall: FAIL (${FAIL_COUNT} check(s) failed). Artifacts: ${OUT_DIR}" >&2
exit 1
