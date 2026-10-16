#!/usr/bin/env bash
# 付与表を、本番ではない Postgres で試す。
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

if [[ "${DATABASE_URL:-}" == *supabase.co* || "${DATABASE_URL:-}" == *supabase.com* ]]; then
  echo "refusing to run against a hosted Supabase URL" >&2
  exit 1
fi

if [[ -n "${DATABASE_URL:-}" ]]; then
  psql_cmd() { psql "$DATABASE_URL" -v ON_ERROR_STOP=1 "$@"; }
else
  psql_cmd() { sudo -u postgres psql -d complimentary_plus_test -v ON_ERROR_STOP=1 "$@"; }
  sudo -u postgres psql -d postgres -v ON_ERROR_STOP=1 -c "drop database if exists complimentary_plus_test;"
  sudo -u postgres psql -d postgres -v ON_ERROR_STOP=1 -c "create database complimentary_plus_test;"
fi

psql_cmd -f supabase/tests/complimentary_plus_bootstrap.sql
psql_cmd -f supabase/migrations/20261016093000_complimentary_plus_grants.sql
psql_cmd -f supabase/tests/complimentary_plus_grants_test.sql

entitlements="$(psql_cmd -tA -c "select count(*) from public.calonavi_plus_entitlements")"
notices="$(psql_cmd -tA -c "select count(*) from public.store_server_notifications")"
psql_cmd -f supabase/rollback/20261016093000_complimentary_plus_grants_down.sql
still_entitlements="$(psql_cmd -tA -c "select count(*) from public.calonavi_plus_entitlements")"
still_notices="$(psql_cmd -tA -c "select count(*) from public.store_server_notifications")"
gone="$(psql_cmd -tA -c "select to_regclass('public.calonavi_plus_complimentary_grants') is null")"
if [[ "$entitlements" != "1" || "$still_entitlements" != "1" || "$notices" != "1" || "$still_notices" != "1" || "$gone" != "t" ]]; then
  echo "rollback touched billing data or left the grant table" >&2
  exit 1
fi
echo "complimentary plus sql tests passed"
