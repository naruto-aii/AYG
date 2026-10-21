#!/usr/bin/env bash
# userlog のマイグレーションを、本番ではない Postgres で試す。
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
  psql_cmd() { sudo -u postgres psql -d userlog_test -v ON_ERROR_STOP=1 "$@"; }
  sudo -u postgres psql -d postgres -v ON_ERROR_STOP=1 -c "drop database if exists userlog_test;"
  sudo -u postgres psql -d postgres -v ON_ERROR_STOP=1 -c "create database userlog_test;"
fi

psql_cmd -f supabase/tests/userlog_notifications_bootstrap.sql
psql_cmd -f supabase/migrations/20261015032420_userlog_notifications.sql
psql_cmd -f supabase/migrations/20261015065812_userlog_login_per_install.sql
psql_cmd -f supabase/migrations/20261017033236_userlog_six_checkpoints.sql
psql_cmd -f supabase/tests/userlog_notifications_test.sql
psql_cmd -c "create extension if not exists pgtap;"
if [[ -n "${DATABASE_URL:-}" ]]; then
  PGOPTIONS="-c client_min_messages=error" pg_prove -d "$DATABASE_URL" supabase/tests/userlog_login_per_install_test.sql
else
  sudo -u postgres env PGOPTIONS="-c client_min_messages=error" pg_prove -d userlog_test supabase/tests/userlog_login_per_install_test.sql
fi
echo "userlog sql tests passed"
