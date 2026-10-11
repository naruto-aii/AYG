#!/usr/bin/env bash
# Applies migrations on a local Postgres, then checks KPI exclusion counts.
# Does not connect to Supabase. Skips the schedule files that need pg_cron,
# and the food-alias load that needs the official foods catalog.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is required" >&2
  exit 1
fi

case "$DATABASE_URL" in
  *supabase.co*|*supabase.com*|*vdzzusqisymtejcjnikb*)
    echo "refusing to run against a Supabase URL" >&2
    exit 1
    ;;
esac

psql_cmd() {
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 "$@"
}

echo "bootstrap"
psql_cmd -f supabase/tests/official_foods_pg_bootstrap.sql

echo "migrations"
while IFS= read -r migration; do
  case "$migration" in
    *20261006200000_food_search_quality.sql|\
    *20261007160000_food_search_spellings_rls.sql|\
    *20261008090100_store_import_schedule.sql|\
    *20261008090300_app_events_retention_schedule.sql)
      echo "skip $migration"
      continue
      ;;
  esac
  echo "apply $migration"
  psql_cmd -f "$migration"
done < <(find supabase/migrations -maxdepth 1 -name '*.sql' | sort)

echo "kpi exclusion counts"
psql_cmd -f supabase/tests/kpi_exclusion_test.sql

echo "rollback"
psql_cmd -f supabase/rollback/20261011063750_kpi_exclusion_by_identity_down.sql

psql_cmd -c "select count(*) from kpi.users where id = '00000000-0000-0000-0000-000000000002';" \
  | grep -q '1' || {
    echo "rollback did not return the apple fixture to kpi.users" >&2
    exit 1
  }

echo "kpi exclusion test ok"
