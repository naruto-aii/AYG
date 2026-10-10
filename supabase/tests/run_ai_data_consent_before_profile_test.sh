#!/usr/bin/env bash
# 初回設定より前の同意を、ローカルの Postgres で確かめる。
# 本番と Supabase には繋がない。
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
psql_cmd -c "create extension if not exists pgtap;"

echo "migrations"
new_migration="supabase/migrations/20261010213000_ai_data_consent_auth_user.sql"
failed=0
while IFS= read -r migration; do
  base="$(basename "$migration")"
  if [[ "$migration" == "$new_migration" ]]; then
    continue
  fi
  case "$base" in
    20261008090100_store_import_schedule.sql|20261008090300_app_events_retention_schedule.sql)
      if ! psql_cmd -tAc "select 1 from pg_available_extensions where name = 'pg_cron'" | grep -q 1; then
        echo "skip $base (pg_cron is not installed; consent does not use it)"
        continue
      fi
      ;;
  esac
  echo "apply $migration"
  if ! psql_cmd -f "$migration"; then
    echo "warn: $base failed; continuing. Consent does not read that migration." >&2
    failed=$((failed + 1))
  fi
done < <(find supabase/migrations -maxdepth 1 -name '*.sql' | sort)
echo "migrations with errors: $failed"
if ! psql_cmd -tAc "select to_regclass('public.ai_data_consents') is not null" | grep -q t; then
  echo "ai_data_consents was not created" >&2
  exit 1
fi

echo "seed existing consent before retargeting the foreign key"
psql_cmd -f supabase/tests/ai_data_consent_before_profile_seed.sql

echo "apply $new_migration"
psql_cmd -f "$new_migration"

echo "pgtap"
tap_log="$(mktemp)"
psql_cmd -f supabase/tests/ai_data_consent_before_profile_test.sql | tee "$tap_log"
if grep -E 'not ok |Looks like you failed|Failed test' "$tap_log" >/dev/null; then
  echo "pgTAP reported failures" >&2
  exit 1
fi

echo "rollback restores the old foreign key and keeps the seeded row"
psql_cmd -f supabase/rollback/20261010213000_ai_data_consent_auth_user_down.sql
psql_cmd -v ON_ERROR_STOP=1 <<'SQL'
do $$
begin
  if not exists (
    select 1
    from public.ai_data_consents
    where user_id = '11111111-1111-4111-8111-111111111111'
      and policy_version = '2026-10-08'
  ) then
    raise exception 'rollback removed the existing consent row';
  end if;
  if not exists (
    select 1
    from pg_constraint c
    join pg_class rel on rel.oid = c.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    join pg_class ref on ref.oid = c.confrelid
    join pg_namespace refn on refn.oid = ref.relnamespace
    where c.conname = 'ai_data_consents_user_id_fkey'
      and nsp.nspname = 'public'
      and rel.relname = 'ai_data_consents'
      and refn.nspname = 'public'
      and ref.relname = 'users'
  ) then
    raise exception 'rollback did not point user_id back at public.users';
  end if;

  insert into auth.users (id, email)
  values ('66666666-6666-4666-8666-666666666666', 'blocked@example.test');
  begin
    insert into public.ai_data_consents (user_id, policy_version)
    values ('66666666-6666-4666-8666-666666666666', '2026-10-10');
    raise exception 'old foreign key accepted a user with no public.users';
  exception
    when foreign_key_violation then
      null;
  end;
end
$$;
SQL

echo "ai data consent before profile: ok"
