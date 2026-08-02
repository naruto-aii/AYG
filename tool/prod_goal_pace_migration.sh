#!/usr/bin/env bash
# Production migration: goals.goal_pace only.
#
# Applies ONLY:
#   supabase/migrations/20260802120000_add_goal_pace_to_goals.sql
#
# Does NOT run prod_phase2b_apply.sh or use supabase link.
# Supabase CLI commands use --db-url only (password percent-encoded in URL).
#
# Usage:
#   # Already applied: post-migration SELECT verification only
#   # Not applied: audit + dry-run, stops before backup/apply
#   ./tool/prod_goal_pace_migration.sh
#
#   # Apply when migration is still pending (requires double confirmation)
#   APPLY_GOAL_PACE=yes CONFIRM_PROJECT_REF=vdzzusqisymtejcjnikb ./tool/prod_goal_pace_migration.sh
#
# Prerequisites:
#   export SUPABASE_DB_PASSWORD='...'
#   export SUPABASE_PROJECT_REF='vdzzusqisymtejcjnikb'  # optional if default matches
#   Or: tool/db_password.local (gitignored)
#
# Secrets (password, full DB URL) are never echoed or written to artifacts.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PG_DUMP="/opt/homebrew/opt/libpq/bin/pg_dump"
PSQL="/opt/homebrew/opt/libpq/bin/psql"
PG_RESTORE="/opt/homebrew/opt/libpq/bin/pg_restore"
SUPABASE_CLI="${SUPABASE_CLI:-supabase}"

MIGRATION_FILE="$ROOT/supabase/migrations/20260802120000_add_goal_pace_to_goals.sql"
MIGRATION_NAME="20260802120000"
MIGRATION_BASENAME="20260802120000_add_goal_pace_to_goals.sql"
REQUIRED_CONFIRM_PROJECT_REF="vdzzusqisymtejcjnikb"

log() { echo "[$(date -u +%H:%M:%S)] $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

require_cmd() {
  local cmd="$1"
  if [[ -x "$cmd" ]] || command -v "$cmd" >/dev/null 2>&1; then
    return 0
  fi
  fail "required command not found: $cmd"
}

# Percent-encode password; emit full CLI DB URL to stdout only (never log).
build_cli_db_url() {
  SUPABASE_PROJECT_REF="$1" SUPABASE_DB_PASSWORD="$2" python3 - <<'PY'
import os
import urllib.parse

project_ref = os.environ["SUPABASE_PROJECT_REF"]
password = os.environ["SUPABASE_DB_PASSWORD"]
encoded = urllib.parse.quote(password, safe="")
print(
    f"postgresql://postgres:{encoded}@db.{project_ref}.supabase.co:5432/postgres",
    end="",
)
PY
}

run_supabase_cli() {
  # Usage: run_supabase_cli <subcommand...>  (must include --db-url "$CLI_DB_URL")
  "$SUPABASE_CLI" "$@"
}

# --- Startup (no DB connection) ---
log "=== Startup self-test (no DB connection) ==="
bash -n "${BASH_SOURCE[0]}"

require_cmd "$PG_DUMP"
require_cmd "$PSQL"
require_cmd "$PG_RESTORE"
require_cmd "$SUPABASE_CLI"
require_cmd python3
require_cmd shasum
require_cmd rg

[[ -f "$MIGRATION_FILE" ]] || fail "migration file not found: $MIGRATION_FILE"

if [[ -z "${SUPABASE_DB_PASSWORD:-}" ]]; then
  if [[ -f "$ROOT/tool/db_password.local" ]]; then
    SUPABASE_DB_PASSWORD="$(<"$ROOT/tool/db_password.local")"
    export SUPABASE_DB_PASSWORD
  fi
fi

[[ -n "${SUPABASE_DB_PASSWORD:-}" ]] || fail "SUPABASE_DB_PASSWORD is not set (or tool/db_password.local missing)."

PROJECT_REF="${SUPABASE_PROJECT_REF:-$REQUIRED_CONFIRM_PROJECT_REF}"
if [[ -z "$PROJECT_REF" && -f "$ROOT/tool/dart_defines.local.json" ]]; then
  PROJECT_REF="$(python3 - <<'PY' "$ROOT/tool/dart_defines.local.json"
import json, sys
url = json.load(open(sys.argv[1])).get("SUPABASE_URL", "")
print(url.replace("https://", "").split(".")[0] if url else "")
PY
)"
fi

[[ -n "$PROJECT_REF" ]] || fail "SUPABASE_PROJECT_REF not set"

CLI_DB_URL="$(build_cli_db_url "$PROJECT_REF" "$SUPABASE_DB_PASSWORD")"
[[ -n "$CLI_DB_URL" ]] || fail "CLI DB URL build returned empty string"
if [[ "$CLI_DB_URL" != postgresql://postgres:*@db.${PROJECT_REF}.supabase.co:5432/postgres ]]; then
  fail "CLI DB URL format unexpected for project ref ${PROJECT_REF}"
fi
log "Startup: CLI DB URL built (not logged)"
log "Startup self-test OK"

# psql/pg_dump: host URL without embedded password + PGPASSWORD
DB_HOST="db.${PROJECT_REF}.supabase.co"
DB_URL="postgresql://postgres@${DB_HOST}:5432/postgres"
export PGPASSWORD="$SUPABASE_DB_PASSWORD"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="${BACKUP_DIR:-${HOME}/Kalonavi_Backups/${TS}_goal_pace_migration}"
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

run_psql() { "$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 "$@"; }
run_psql_tsv() { "$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 -At "$@"; }

# --- Phase A: Migration audit ---
log "=== Phase A: Migration audit ==="
log "Project ref: ${PROJECT_REF}"
log "Backup dir: ${BACKUP_DIR}"

MIGRATION_SHA="$(shasum -a 256 "$MIGRATION_FILE" | awk '{print $1}')"
log "Migration SHA-256: ${MIGRATION_SHA}"
echo "migration_sha256=${MIGRATION_SHA}" >"$BACKUP_DIR/phase_a_audit.txt"
echo "migration_file=${MIGRATION_BASENAME}" >>"$BACKUP_DIR/phase_a_audit.txt"

if rg -qi '^\s*(delete|truncate)\s' "$MIGRATION_FILE"; then
  fail "migration contains DELETE/TRUNCATE"
fi
if rg -qi 'drop\s+(table|column)\s' "$MIGRATION_FILE"; then
  fail "migration contains DROP TABLE/COLUMN"
fi
if ! rg -q 'add column if not exists goal_pace' "$MIGRATION_FILE"; then
  fail "migration missing add column goal_pace"
fi
log "Static audit: no DELETE/TRUNCATE/DROP TABLE/COLUMN — OK"
echo "static_audit=pass" >>"$BACKUP_DIR/phase_a_audit.txt"

log "Phase A.6: supabase migration list --db-url"
MIGRATION_LIST_OUT="$BACKUP_DIR/migration_list.txt"
run_supabase_cli migration list --db-url "$CLI_DB_URL" 2>&1 | tee "$MIGRATION_LIST_OUT"

MIGRATION_LIST_PARSED="$(python3 - <<'PY' "$MIGRATION_LIST_OUT" "$MIGRATION_NAME"
import re, sys

text = open(sys.argv[1]).read()
target = sys.argv[2]
rows = []
for line in text.splitlines():
    if not re.search(r"\d{14}", line):
        continue
    parts = [p.strip() for p in line.split("|")]
    if len(parts) < 2:
        continue
    local, remote = parts[0], parts[1]
    if target in local or target in remote:
        rows.append((local, remote))

if not rows:
    print("status=missing")
    print("detail=target migration not found in migration list")
    raise SystemExit(0)

local_ok = any(target in local for local, _ in rows)
remote_ok = any(target in remote for _, remote in rows)
synced = local_ok and remote_ok and all(
    target in local and target in remote for local, remote in rows
)

print(f"status={'synced' if synced else 'unsynced'}")
print(f"local_present={'yes' if local_ok else 'no'}")
print(f"remote_present={'yes' if remote_ok else 'no'}")
for local, remote in rows:
    print(f"target_line={local} | {remote}")
PY
)"
log "Migration list parsed:"
while IFS= read -r line; do
  log "  $line"
done <<<"$MIGRATION_LIST_PARSED"

MIGRATION_SYNC_STATUS="$(printf '%s\n' "$MIGRATION_LIST_PARSED" | awk -F= '/^status=/{print $2}')"
[[ "$MIGRATION_SYNC_STATUS" == "synced" ]] || fail "migration ${MIGRATION_NAME} not present in both Local and Remote"
log "Migration list: ${MIGRATION_NAME} synced Local/Remote — OK"
echo "migration_list_synced=pass" >>"$BACKUP_DIR/phase_a_audit.txt"

log "Phase A.7: supabase db push --dry-run --db-url"
DRY_RUN_OUT="$BACKUP_DIR/db_push_dry_run.txt"
run_supabase_cli db push --dry-run --db-url "$CLI_DB_URL" 2>&1 | tee "$DRY_RUN_OUT"

DRY_RUN_PARSED="$(python3 - <<'PY' "$DRY_RUN_OUT" "$MIGRATION_NAME"
import re, sys

text = open(sys.argv[1]).read()
target = sys.argv[2]
lower = text.lower()
up_to_date = "remote database is up to date" in lower
found = set(re.findall(r"202\d{11}", text))
other = sorted(found - {target})

if up_to_date:
    print("status=already_applied")
elif target in found:
    print("status=pending_target")
elif found:
    print("status=pending_other")
    print("other_pending=" + ",".join(other))
else:
    print("status=unknown")
PY
)"
log "Dry-run parsed:"
while IFS= read -r line; do
  log "  $line"
done <<<"$DRY_RUN_PARSED"

DRY_RUN_STATUS="$(printf '%s\n' "$DRY_RUN_PARSED" | awk -F= '/^status=/{print $2}')"
OTHER_PENDING="$(printf '%s\n' "$DRY_RUN_PARSED" | awk -F= '/^other_pending=/{print $2}')"

ALREADY_APPLIED=no
case "$DRY_RUN_STATUS" in
  already_applied)
    ALREADY_APPLIED=yes
    log "Dry-run: Remote database is up to date — migration already applied"
    echo "dry_run_already_applied=pass" >>"$BACKUP_DIR/phase_a_audit.txt"
    ;;
  pending_target)
    log "Dry-run: ${MIGRATION_NAME} is pending apply"
    echo "dry_run_pending_target=pass" >>"$BACKUP_DIR/phase_a_audit.txt"
    ;;
  pending_other)
    fail "db push --dry-run shows pending migrations besides ${MIGRATION_NAME}: ${OTHER_PENDING}"
    ;;
  *)
    fail "db push --dry-run result unexpected (status=${DRY_RUN_STATUS})"
    ;;
esac

if [[ "$ALREADY_APPLIED" == "yes" ]]; then
  log "=== Phase D: Post-migration read-only verification (already applied) ==="
  PHASE_D_ONLY=yes
elif [[ "${APPLY_GOAL_PACE:-}" != "yes" ]]; then
  log "STOP: Phase A complete (migration pending, no apply). Set APPLY_GOAL_PACE=yes CONFIRM_PROJECT_REF=${REQUIRED_CONFIRM_PROJECT_REF} to backup+apply."
  exit 0
fi

# --- Phase B/C: backup + apply (only when migration still pending) ---
if [[ "${PHASE_D_ONLY:-}" != "yes" ]]; then
  [[ "${APPLY_GOAL_PACE:-}" == "yes" ]] || fail "internal: reached Phase B without APPLY_GOAL_PACE=yes"
  [[ "${CONFIRM_PROJECT_REF:-}" == "$REQUIRED_CONFIRM_PROJECT_REF" ]] || fail "CONFIRM_PROJECT_REF must be ${REQUIRED_CONFIRM_PROJECT_REF}"

  log "=== Phase B: Production backup ==="

log "Pre-migration goals probe"
run_psql -c "
select exists (
  select 1 from information_schema.columns
  where table_schema='public' and table_name='goals' and column_name='goal_pace'
) as goal_pace_exists;
" | tee "$BACKUP_DIR/pre_migration_goals_probe.txt"

GOAL_PACE_EXISTS="$(run_psql_tsv -c "
select exists (
  select 1 from information_schema.columns
  where table_schema='public' and table_name='goals' and column_name='goal_pace'
);
")"

{
  echo "=== goals row count ==="
  run_psql -c "select count(*) as goals_row_count from public.goals;"
  echo
  echo "=== goals RLS ==="
  run_psql -c "
select c.relname, c.relrowsecurity as rls_enabled
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname='goals';"
  echo
  echo "=== goals policies ==="
  run_psql -c "
select pol.polname, pol.polcmd
from pg_policy pol
join pg_class rel on rel.oid=pol.polrelid
join pg_namespace nsp on nsp.oid=rel.relnamespace
where nsp.nspname='public' and rel.relname='goals'
order by pol.polname;"
  echo
  echo "=== goals grants ==="
  run_psql -c "
select grantee, privilege_type
from information_schema.role_table_grants
where table_schema='public' and table_name='goals'
order by grantee, privilege_type;"
} | tee "$BACKUP_DIR/pre_migration_goals_rls_grants.txt"

PRE_GOALS_COUNT="$(run_psql_tsv -c "select count(*) from public.goals;")"
PRE_POLICY_COUNT="$(run_psql_tsv -c "
select count(*)::text from pg_policy pol
join pg_class rel on rel.oid=pol.polrelid
join pg_namespace nsp on nsp.oid=rel.relnamespace
where nsp.nspname='public' and rel.relname='goals';")"
PRE_RLS_ENABLED="$(run_psql_tsv -c "
select c.relrowsecurity::text from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname='goals';")"

log "Creating backups"
"$PG_DUMP" "$DB_URL" --format=custom --file="$BACKUP_DIR/full_backup.dump"
"$PG_DUMP" "$DB_URL" --schema-only --file="$BACKUP_DIR/schema_only.sql"
"$PG_DUMP" "$DB_URL" --data-only --file="$BACKUP_DIR/data_only.sql"

{
  echo "timestamp=${TS}"
  echo "project_ref=${PROJECT_REF}"
  echo "migration=${MIGRATION_BASENAME}"
  echo "migration_sha256=${MIGRATION_SHA}"
  echo "goal_pace_exists_before=${GOAL_PACE_EXISTS}"
  echo "goals_row_count_before=${PRE_GOALS_COUNT}"
  echo "goals_policy_count_before=${PRE_POLICY_COUNT}"
  echo "goals_rls_enabled_before=${PRE_RLS_ENABLED}"
} >"$BACKUP_DIR/backup_metadata.txt"

shasum -a 256 "$BACKUP_DIR"/* >"$BACKUP_DIR/checksums.sha256"
shasum -a 256 -c "$BACKUP_DIR/checksums.sha256"

log "pg_restore --list"
"$PG_RESTORE" --list "$BACKUP_DIR/full_backup.dump" >"$BACKUP_DIR/pg_restore_list.txt"

for f in full_backup.dump schema_only.sql data_only.sql checksums.sha256 pg_restore_list.txt; do
  [[ -s "$BACKUP_DIR/$f" ]] || fail "backup file missing or empty: $f"
done
log "Phase B backup verification OK"

[[ "${CONFIRM_PROJECT_REF:-}" == "$REQUIRED_CONFIRM_PROJECT_REF" ]] || fail "CONFIRM_PROJECT_REF must be ${REQUIRED_CONFIRM_PROJECT_REF}"

CURRENT_SHA="$(shasum -a 256 "$MIGRATION_FILE" | awk '{print $1}')"
[[ "$CURRENT_SHA" == "$MIGRATION_SHA" ]] || fail "Migration SHA changed before apply (${MIGRATION_SHA} -> ${CURRENT_SHA})"
log "Pre-apply SHA-256 reconfirmed: ${CURRENT_SHA}"

if [[ "$GOAL_PACE_EXISTS" == "t" ]]; then
  log "goal_pace column already exists — skipping db push (idempotent)."
else
  log "=== Phase C: supabase db push --db-url (single pending migration expected) ==="
  run_supabase_cli db push --dry-run --db-url "$CLI_DB_URL" 2>&1 | tee "$BACKUP_DIR/db_push_dry_run_pre_apply.txt"
  if rg -q '20260722130000|20260723120000|20260727120000|20260729120000|20260728120000|20260801120000|20260801180000|20260801200000' "$BACKUP_DIR/db_push_dry_run_pre_apply.txt"; then
    fail "pre-apply dry-run lists already-applied migrations — aborting"
  fi
  run_supabase_cli db push --db-url "$CLI_DB_URL" --yes
  fi
fi

log "=== Phase D: Post-migration read-only verification ==="
GOALS_COUNT="$(run_psql_tsv -c "select count(*) from public.goals;")"
POLICY_COUNT="$(run_psql_tsv -c "
select count(*)::text from pg_policy pol
join pg_class rel on rel.oid=pol.polrelid
join pg_namespace nsp on nsp.oid=rel.relnamespace
where nsp.nspname='public' and rel.relname='goals';")"
RLS_ENABLED="$(run_psql_tsv -c "
select c.relrowsecurity::text from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname='goals';")"
ANON_GRANT_COUNT="$(run_psql_tsv -c "
select count(*)::text from information_schema.role_table_grants
where table_schema='public' and table_name='goals' and grantee='anon';")"
AUTH_GRANTS="$(run_psql_tsv -c "
select coalesce(string_agg(privilege_type, ',' order by privilege_type), '')
from information_schema.role_table_grants
where table_schema='public' and table_name='goals' and grantee='authenticated';")"

{
  echo "=== goal_pace column ==="
  run_psql -c "
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema='public' and table_name='goals' and column_name='goal_pace';"
  echo
  echo "=== check constraint ==="
  run_psql -c "
select conname, pg_get_constraintdef(oid)
from pg_constraint
where conrelid='public.goals'::regclass and conname='goals_goal_pace_check';"
  echo
  echo "=== goal_pace distribution ==="
  run_psql -c "
select
  count(*) as total,
  count(goal_pace) as non_null,
  count(*) filter (where goal_pace is null) as null_count
from public.goals;"
  echo
  echo "=== invalid goal_pace values ==="
  run_psql -c "
select count(*) as invalid_count
from public.goals
where goal_pace is not null and goal_pace not in ('slow','standard');"
  echo
  echo "=== goals RLS ==="
  run_psql -c "
select c.relname, c.relrowsecurity as rls_enabled
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname='goals';"
  echo
  echo "=== goals policies ==="
  run_psql -c "
select pol.polname, pol.polcmd
from pg_policy pol
join pg_class rel on rel.oid=pol.polrelid
join pg_namespace nsp on nsp.oid=rel.relnamespace
where nsp.nspname='public' and rel.relname='goals'
order by pol.polname;"
  echo
  echo "=== goals grants ==="
  run_psql -c "
select grantee, privilege_type
from information_schema.role_table_grants
where table_schema='public' and table_name='goals'
order by grantee, privilege_type;"
  echo
  echo "goals_row_count=${GOALS_COUNT}"
  echo "policy_count=${POLICY_COUNT}"
  echo "rls_enabled=${RLS_ENABLED}"
  echo "anon_grant_count=${ANON_GRANT_COUNT}"
  echo "authenticated_grants=${AUTH_GRANTS}"
  if [[ -n "${PRE_GOALS_COUNT:-}" ]]; then
    echo "goals_row_count_before=${PRE_GOALS_COUNT}"
  fi
} | tee "$BACKUP_DIR/post_migration_verification.txt"

[[ "$RLS_ENABLED" == "t" ]] || fail "goals RLS is not enabled"
[[ "$POLICY_COUNT" == "4" ]] || fail "goals policy count expected 4, got ${POLICY_COUNT}"
[[ "$ANON_GRANT_COUNT" == "0" ]] || fail "anon should have no grants on goals, got ${ANON_GRANT_COUNT}"
[[ "$AUTH_GRANTS" == "INSERT,SELECT,UPDATE" ]] || fail "authenticated grants unexpected: ${AUTH_GRANTS}"

COLUMN_OK="$(run_psql_tsv -c "
select case when exists (
  select 1 from information_schema.columns
  where table_schema='public' and table_name='goals'
    and column_name='goal_pace' and data_type='text' and is_nullable='YES'
) then 'ok' else 'bad' end;")"
[[ "$COLUMN_OK" == "ok" ]] || fail "goal_pace column definition unexpected"

CHECK_DEF="$(run_psql_tsv -c "
select pg_get_constraintdef(oid)
from pg_constraint
where conrelid='public.goals'::regclass and conname='goals_goal_pace_check';")"
[[ "$CHECK_DEF" == *slow* && "$CHECK_DEF" == *standard* && "$CHECK_DEF" == *NULL* ]] \
  || fail "goals_goal_pace_check constraint unexpected"

INVALID="$(run_psql_tsv -c "
select count(*) from public.goals
where goal_pace is not null and goal_pace not in ('slow','standard');")"
[[ "$INVALID" == "0" ]] || fail "invalid goal_pace values found: ${INVALID}"

if [[ -n "${PRE_GOALS_COUNT:-}" ]]; then
  [[ "$PRE_GOALS_COUNT" == "$GOALS_COUNT" ]] || fail "goals row count changed (${PRE_GOALS_COUNT} -> ${GOALS_COUNT})"
  [[ "$PRE_POLICY_COUNT" == "$POLICY_COUNT" ]] || fail "goals policy count changed"
  [[ "$PRE_RLS_ENABLED" == "$RLS_ENABLED" ]] || fail "goals RLS changed"
fi

log "Phase D.8: migration list synced + dry-run up to date"
run_supabase_cli migration list --db-url "$CLI_DB_URL" 2>&1 | tee "$BACKUP_DIR/migration_list_post.txt"
run_supabase_cli db push --dry-run --db-url "$CLI_DB_URL" 2>&1 | tee "$BACKUP_DIR/db_push_dry_run_post.txt"
if ! rg -qi 'remote database is up to date' "$BACKUP_DIR/db_push_dry_run_post.txt"; then
  fail "post-verification dry-run is not up to date"
fi

log "Phase D complete. Review ${BACKUP_DIR}"
