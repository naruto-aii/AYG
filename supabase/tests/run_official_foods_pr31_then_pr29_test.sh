#!/usr/bin/env bash
# Apply this branch's official-foods migrations first, then PR #29.
# Timestamp order is the other way around. PR #29 revokes saved_foods
# INSERT/UPDATE and grants a column list. When that revoke runs after the
# provenance columns exist, 20260927150000 must grant those columns again.
# This job fetches that branch's latest head and writes a My Food as
# authenticated.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is required" >&2
  exit 1
fi

case "$DATABASE_URL" in
  *supabase.co*|*supabase.com*|*supabase_*)
    echo "refusing to run against a Supabase URL" >&2
    exit 1
    ;;
esac

ref="${PR29_GIT_REF:-origin/cursor/apple-token-revoke-on-delete-eb80}"
if ! git rev-parse --verify --quiet "$ref" >/dev/null; then
  git fetch origin cursor/apple-token-revoke-on-delete-eb80
fi
echo "PR #29 head $(git rev-parse "$ref")"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

pr29_migrations=(
  20260927120000_reject_banned_public_food_names.sql
  20260927140000_subscription_events.sql
  20260927150000_protect_owner_deleted_and_revoke_sessions.sql
  20260927160000_delete_subscription_events_on_account_deletion.sql
  20260927170000_store_apple_refresh_tokens.sql
  20260927180000_delete_own_account_service_role_only.sql
)

mkdir -p "$work/pr29" "$work/vault"
for file in "${pr29_migrations[@]}"; do
  git show "$ref:supabase/migrations/$file" > "$work/pr29/$file"
done
git show "$ref:supabase/tests/pg_ext/supabase_vault.control" \
  > "$work/vault/supabase_vault.control"
git show "$ref:supabase/tests/pg_ext/supabase_vault--1.0.sql" \
  > "$work/vault/supabase_vault--1.0.sql"

psql_cmd() {
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 "$@"
}

install_vault() {
  local available
  available="$(psql_cmd -Atc \
    "select count(*) from pg_available_extensions where name = 'supabase_vault';")"
  if [[ "$available" != "0" ]]; then
    return 0
  fi
  local dest="${PR29_VAULT_SHAREDIR:-}"
  if [[ -z "$dest" ]]; then
    local version major
    version="$(psql_cmd -Atc "show server_version_num;")"
    major="${version:0:2}"
    dest="/usr/share/postgresql/${major}/extension"
  fi
  if [[ ! -d "$dest" ]]; then
    echo "Postgres extension directory not found: $dest" >&2
    exit 1
  fi
  sudo cp "$work/vault/supabase_vault.control" "$dest/"
  sudo cp "$work/vault/supabase_vault--1.0.sql" "$dest/"
}

echo "vault stand-in"
install_vault

echo "bootstrap"
psql_cmd -f supabase/tests/official_foods_pg_bootstrap.sql

echo "migrations before either PR"
while IFS= read -r migration; do
  base="$(basename "$migration")"
  if [[ "$base" > "20260927120000" || "$base" == 2026092712* || "$base" == 20260928* ]]; then
    continue
  fi
  echo "apply $migration"
  psql_cmd -f "$migration"
done < <(find supabase/migrations -maxdepth 1 -name '*.sql' | sort)

echo "official foods migrations first"
psql_cmd -f supabase/migrations/20260928120000_official_foods.sql
psql_cmd -f supabase/migrations/20260928140000_official_food_provenance.sql

echo "PR #29 migrations after"
psql_cmd -c 'create schema if not exists vault;'
for file in "${pr29_migrations[@]}"; do
  echo "apply $file"
  psql_cmd -f "$work/pr29/$file"
done

echo "one official food"
psql_cmd <<'SQL'
insert into public.official_foods (food_code, name, normalized_name)
values ('01088', 'こめ', 'こめ');
SQL

echo "authenticated my food write"
psql_cmd -f supabase/tests/official_foods_with_pr29_test.sql

echo "official foods then PR #29 ok"
