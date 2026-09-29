#!/usr/bin/env bash
# Two connections: one deletes a composition-table copy and has not
# committed; the other upserts that same key with the copy's copied_from,
# source_type copied, no food code, and no attribution.
# PostgREST shape: ON CONFLICT (user_id, food_id) DO UPDATE
# (Prefer: resolution=merge-duplicates, on_conflict=user_id,food_id).
# The upsert must fail with the copied_from error. A plain edit succeeds.
set -euo pipefail

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is required" >&2
  exit 1
fi

psql_cmd() {
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 "$@"
}

owner="cccccccc-0000-4000-8000-0000000000e1"
copier="dddddddd-0000-4000-8000-0000000000e2"

echo "race setup and ordinary upsert"
psql_cmd <<SQL
insert into auth.users (id, email) values
  ('${owner}', 'race-owner@t.local'),
  ('${copier}', 'race-copier@t.local');
insert into public.users (id, email) values
  ('${owner}', 'race-owner@t.local'),
  ('${copier}', 'race-copier@t.local');

insert into public.saved_foods (
  user_id, food_id, name, normalized_name, base_amount, unit_type,
  source_type, official_food_code, official_food_name, visibility
) values (
  '${owner}', 'race-src', '同時実行元', '同時実行元', 100, 'g',
  'mext_sfct', '01088', 'こめ　［水稲めし］　精白米　うるち米', 'private'
);

begin;
select ayg_test.set_auth('${owner}');
select public.publish_saved_food('race-src');
commit;

begin;
select ayg_test.set_auth('${copier}');
insert into public.saved_foods (
  user_id, food_id, name, normalized_name, base_amount, unit_type,
  source_type, copied_from_food_id, copied_from_owner_user_id, visibility
) values (
  '${copier}', 'race-copy', '同時実行写し', '同時実行写し', 100, 'g',
  'copied', 'race-src', '${owner}', 'private'
);
commit;

update public.saved_foods
set visibility = 'private'
where user_id = '${owner}' and food_id = 'race-src';

begin;
select ayg_test.set_auth('${copier}');
insert into public.saved_foods (
  user_id, food_id, name, normalized_name, base_amount, unit_type,
  source_type, official_food_code, official_food_name, source_attribution,
  copied_from_food_id, copied_from_owner_user_id, use_count, visibility
) values (
  '${copier}', 'race-copy', '普通の編集', '普通の編集', 100, 'g',
  'mext_sfct', '01088', 'こめ　［水稲めし］　精白米　うるち米',
  '出典：日本食品標準成分表（八訂）増補2023年（文部科学省）を加工して作成',
  'race-src', '${owner}', 2, 'private'
)
on conflict (user_id, food_id) do update set
  name = excluded.name,
  normalized_name = excluded.normalized_name,
  use_count = excluded.use_count,
  source_type = excluded.source_type,
  official_food_code = excluded.official_food_code,
  official_food_name = excluded.official_food_name,
  source_attribution = excluded.source_attribution,
  copied_from_food_id = excluded.copied_from_food_id,
  copied_from_owner_user_id = excluded.copied_from_owner_user_id,
  visibility = excluded.visibility;
commit;
SQL

got_name="$(psql_cmd -tA -c "select name from public.saved_foods where user_id = '${copier}' and food_id = 'race-copy'")"
if [[ "$got_name" != "普通の編集" ]]; then
  echo "ordinary upsert did not edit the copy: ${got_name}" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

echo "race: uncommitted delete, then upsert"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -X >"$tmpdir/c1.out" 2>"$tmpdir/c1.err" <<SQL &
begin;
delete from public.saved_foods
where user_id = '${copier}' and food_id = 'race-copy';
select pg_sleep(15) as race_upsert_hold;
commit;
SQL
c1_pid=$!

ready=0
for _ in $(seq 1 50); do
  hit="$(psql_cmd -tA -c "select 1 from pg_stat_activity where query like '%race_upsert_hold%' and state = 'active' and pid <> pg_backend_pid() limit 1")"
  if [[ "$hit" == "1" ]]; then
    ready=1
    break
  fi
  sleep 0.2
done
if [[ "$ready" -ne 1 ]]; then
  echo "delete transaction did not reach pg_sleep" >&2
  cat "$tmpdir/c1.err" >&2 || true
  wait "$c1_pid" || true
  exit 1
fi

set +e
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -X >"$tmpdir/c2.out" 2>"$tmpdir/c2.err" <<SQL
set statement_timeout = '25s';
begin;
select ayg_test.set_auth('${copier}');
insert into public.saved_foods (
  user_id, food_id, name, normalized_name, base_amount, unit_type,
  source_type, official_food_code, official_food_name, source_attribution,
  copied_from_food_id, copied_from_owner_user_id, visibility
) values (
  '${copier}', 'race-copy', '出典なし公開', '出典なし公開', 100, 'g',
  'copied', null, null, null,
  'race-src', '${owner}', 'public'
)
on conflict (user_id, food_id) do update set
  name = excluded.name,
  normalized_name = excluded.normalized_name,
  source_type = excluded.source_type,
  official_food_code = excluded.official_food_code,
  official_food_name = excluded.official_food_name,
  source_attribution = excluded.source_attribution,
  copied_from_food_id = excluded.copied_from_food_id,
  copied_from_owner_user_id = excluded.copied_from_owner_user_id,
  visibility = excluded.visibility;
commit;
SQL
c2_status=$?
set -e

wait "$c1_pid" || {
  echo "delete connection failed" >&2
  cat "$tmpdir/c1.err" >&2
  exit 1
}

if [[ "$c2_status" -eq 0 ]]; then
  echo "race upsert inserted a row while its delete was uncommitted" >&2
  cat "$tmpdir/c2.out" >&2
  exit 1
fi
if ! grep -q "copied_from must reference your own saved food or a public saved food" "$tmpdir/c2.err"; then
  echo "race upsert failed with a different error" >&2
  cat "$tmpdir/c2.err" >&2
  exit 1
fi

psql_cmd <<SQL
do \$\$
begin
  if exists (
    select 1
    from public.saved_foods
    where user_id = '${copier}' and food_id = 'race-copy'
  ) then
    raise exception 'race left the copy in place';
  end if;
end
\$\$;
SQL

echo "upsert delete race rejected"
