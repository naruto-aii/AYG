#!/usr/bin/env bash
# Apply PR #31's migrations, load all 2,538 official foods, and run acceptance.
# Local Postgres and CI only. Refuses a Supabase URL.
set -euo pipefail

: "${DATABASE_URL:?DATABASE_URL is required}"
: "${FEATURE_DIR:?FEATURE_DIR is required}"
: "${ACCEPT_DIR:?ACCEPT_DIR is required}"

case "$DATABASE_URL" in
  *supabase.co*|*supabase.com*|*supabase_*)
    echo "refusing DATABASE_URL that looks like hosted Supabase" >&2
    exit 1
    ;;
esac

psql_cmd() {
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 "$@"
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

data_sha="0d5a77077dd6cd91cbc2e6e317b8b218a38728c409eed452f1c10635a0d3099c"
errata_sha="fb61037c7f66af0db1fb0729977913a629bc17097bc3ff7bf75217f9110acabb"
data_url="https://www.mext.go.jp/content/20260327-mxt_kagsei-mext-000029402_02.xlsx"
errata_url="https://www.mext.go.jp/content/20260327-mxt_kagsei-mext-000029402_16.xlsx"

echo "download workbook"
curl -fsSL -o "$work/ch2.xlsx" "$data_url"
curl -fsSL -o "$work/errata.xlsx" "$errata_url"
echo "$data_sha  $work/ch2.xlsx" | sha256sum -c -
echo "$errata_sha  $work/errata.xlsx" | sha256sum -c -

echo "convert"
python3 "$FEATURE_DIR/tool/official_foods/convert.py" \
  --xlsx "$work/ch2.xlsx" \
  --errata "$work/errata.xlsx" \
  --out "$work/official_foods.csv"

echo "bootstrap"
psql_cmd -f "$FEATURE_DIR/supabase/tests/official_foods_pg_bootstrap.sql"

echo "migrations before official foods"
while IFS= read -r migration; do
  base="$(basename "$migration")"
  if [[ "$base" == "20260928120000_official_foods.sql" || "$base" == "20260928140000_official_food_provenance.sql" ]]; then
    continue
  fi
  echo "apply $base"
  psql_cmd -f "$migration"
done < <(find "$FEATURE_DIR/supabase/migrations" -maxdepth 1 -name '*.sql' | sort)

echo "snapshot"
psql_cmd -f "$ACCEPT_DIR/supabase/acceptance/official_foods/snapshot_user_tables.sql" \
  -tA -o "$work/snap.raw"
python3 - "$work/snap.raw" "$work/baseline.json" <<'PY'
import json
import sys
raw, dest = sys.argv[1], sys.argv[2]
line = next(item for item in open(raw, encoding="utf-8") if item.startswith("{"))
data = json.loads(line)
if data.get("kind") != "official_foods_user_table_snapshot":
    raise SystemExit("snapshot kind mismatch")
if "official_foods" in data.get("tables", {}):
    raise SystemExit("snapshot already contains official_foods")
open(dest, "w", encoding="utf-8").write(line.strip())
print(f"snapshot tables={len(data['tables'])}")
PY

for official in \
  "$FEATURE_DIR/supabase/migrations/20260928120000_official_foods.sql" \
  "$FEATURE_DIR/supabase/migrations/20260928140000_official_food_provenance.sql"
do
  if [[ ! -f "$official" ]]; then
    echo "missing migration $official" >&2
    exit 1
  fi
  echo "apply $(basename "$official")"
  psql_cmd -f "$official"
done

aliases="$FEATURE_DIR/supabase/seed/official_food_aliases.csv"
if [[ -f "$FEATURE_DIR/tool/official_foods/export_sql.py" ]]; then
  echo "load via export_sql.py"
  python3 "$FEATURE_DIR/tool/official_foods/export_sql.py" \
    --foods "$work/official_foods.csv" \
    --aliases "$aliases" \
    --out-dir "$work/batches" \
    --batch-size 200
  mapfile -t batches < <(find "$work/batches" -type f -name '*.sql' | sort)
  if [[ "${#batches[@]}" -eq 0 ]]; then
    echo "export_sql.py wrote no sql files" >&2
    exit 1
  fi
  for batch in "${batches[@]}"; do
    echo "apply batch $(basename "$batch")"
    psql_cmd -f "$batch"
  done
else
  echo "export_sql.py is not on the feature tree; loading this local database with import.py"
  DATABASE_URL="$DATABASE_URL" python3 "$FEATURE_DIR/tool/official_foods/import.py" \
    --foods "$work/official_foods.csv" \
    --aliases "$aliases"
fi

echo "accept"
python3 - "$ACCEPT_DIR/supabase/acceptance/official_foods/accept_official_foods.sql" \
  "$work/baseline.json" "$work/accept.sql" <<'PY'
import pathlib
import sys
src, baseline_path, dest = sys.argv[1:]
acc = pathlib.Path(src).read_text(encoding="utf-8")
baseline = pathlib.Path(baseline_path).read_text(encoding="utf-8").strip()
if "$of_baseline$" in baseline:
    raise SystemExit("baseline contains the dollar-quote delimiter")
old = "  v_baseline jsonb := null;"
if acc.count(old) != 1:
    raise SystemExit(f"baseline anchor count is {acc.count(old)}")
new = "  v_baseline jsonb := $of_baseline$\n" + baseline + "\n  $of_baseline$::jsonb;"
pathlib.Path(dest).write_text(acc.replace(old, new, 1), encoding="utf-8")
PY
psql_cmd -f "$work/accept.sql"
echo "acceptance finished"

prov_down="$FEATURE_DIR/supabase/rollback/20260928140000_official_food_provenance_down.sql"
foods_down="$FEATURE_DIR/supabase/rollback/20260928120000_official_foods_down.sql"
if [[ ! -f "$prov_down" || ! -f "$foods_down" ]]; then
  echo "missing rollback sql" >&2
  exit 1
fi

# Each down file commits itself. Seed first, then run the files as they ship.
# A second run of each file must succeed; that is what allows the runbook to
# say the down can be executed twice.
echo "seed rollback fixtures"
psql_cmd <<'SQL'
begin;
insert into auth.users (id) values
  ('00000000-0000-4000-8000-000000000091'),
  ('00000000-0000-4000-8000-000000000092');
insert into public.users (id) values
  ('00000000-0000-4000-8000-000000000091'),
  ('00000000-0000-4000-8000-000000000092');
select set_config('ayg.allow_saved_food_publish', 'on', true);
insert into public.saved_foods (
  user_id, food_id, visibility, status, name, normalized_name,
  base_amount, unit_type, kcal_per_base, source_type,
  official_food_code, official_food_name
) values (
  '00000000-0000-4000-8000-000000000091', 'of-rb-mext', 'public', 'active',
  'rb mext', 'rb mext', 100, 'g', 156, 'mext_sfct', '01088', 'rb-official-name'
);
insert into public.saved_foods (
  user_id, food_id, visibility, status, name, normalized_name,
  base_amount, unit_type, kcal_per_base, source_type,
  official_food_code, official_food_name
) values (
  '00000000-0000-4000-8000-000000000091', 'of-rb-private', 'private', 'active',
  'rb private', 'rb private', 100, 'g', 156, 'mext_sfct', '01088', 'rb-official-name'
);
alter table public.saved_foods disable trigger enforce_mext_saved_food_attribution;
insert into public.saved_foods (
  user_id, food_id, visibility, status, name, normalized_name,
  base_amount, unit_type, kcal_per_base, source_type,
  copied_from_food_id, copied_from_owner_user_id
) values (
  '00000000-0000-4000-8000-000000000092', 'of-rb-copy', 'public', 'active',
  'rb copy', 'rb copy', 120, 'g', 156, 'copied',
  'of-rb-mext', '00000000-0000-4000-8000-000000000091'
);
alter table public.saved_foods enable trigger enforce_mext_saved_food_attribution;
commit;
SQL

assert_after_provenance() {
  psql_cmd <<'SQL'
do $$
declare
  n bigint;
  vis text;
  src text;
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'saved_foods'
      and column_name = 'source_attribution'
  ) then
    raise exception 'ACCEPTANCE FAIL: provenance down left source_attribution';
  end if;
  select count(*) into n
  from public.saved_foods
  where visibility = 'public'
    and food_id in ('of-rb-mext', 'of-rb-copy');
  if n <> 0 then
    raise exception 'ACCEPTANCE FAIL: provenance rollback left % public mext-derived rows', n;
  end if;
  select count(*) into n
  from public.saved_foods
  where visibility = 'public' and source_type = 'mext_sfct';
  if n <> 0 then
    raise exception 'ACCEPTANCE FAIL: public mext_sfct rows remain after provenance rollback: %', n;
  end if;
  select visibility, source_type into vis, src
  from public.saved_foods
  where food_id = 'of-rb-private';
  if vis is distinct from 'private' or src is distinct from 'mext_sfct' then
    raise exception 'ACCEPTANCE FAIL: private mext row changed during provenance rollback (% / %)', vis, src;
  end if;
end
$$;
SQL
}

assert_after_foods() {
  psql_cmd <<'SQL'
do $$
declare
  n bigint;
  vis text;
  src text;
begin
  select count(*) into n
  from public.saved_foods
  where visibility = 'public'
    and food_id in ('of-rb-mext', 'of-rb-copy', 'of-rb-private');
  if n <> 0 then
    raise exception 'ACCEPTANCE FAIL: rollback left % public mext-derived rows', n;
  end if;
  select count(*) into n
  from public.saved_foods
  where source_type = 'mext_sfct';
  if n <> 0 then
    raise exception 'ACCEPTANCE FAIL: mext_sfct rows remain after foods rollback: %', n;
  end if;
  select visibility, source_type into vis, src
  from public.saved_foods
  where food_id = 'of-rb-mext';
  if vis is distinct from 'private' or src is distinct from 'copied' then
    raise exception 'ACCEPTANCE FAIL: public mext row after rollback is % / %', vis, src;
  end if;
  select visibility into vis
  from public.saved_foods
  where food_id = 'of-rb-copy';
  if vis is distinct from 'private' then
    raise exception 'ACCEPTANCE FAIL: public mext copy after rollback is %', vis;
  end if;
  select visibility, source_type into vis, src
  from public.saved_foods
  where food_id = 'of-rb-private';
  if vis is distinct from 'private' or src is distinct from 'copied' then
    raise exception 'ACCEPTANCE FAIL: private mext row after rollback is % / %', vis, src;
  end if;
  if to_regclass('public.official_foods') is not null then
    raise exception 'ACCEPTANCE FAIL: official_foods still exists after rollback';
  end if;
  if not exists (select 1 from pg_extension where extname = 'pg_trgm') then
    raise exception 'ACCEPTANCE FAIL: rollback dropped pg_trgm';
  end if;
end
$$;
SQL
}

echo "provenance down"
psql_cmd -f "$prov_down"
assert_after_provenance
echo "provenance down again"
psql_cmd -f "$prov_down"
assert_after_provenance
echo "official foods down"
psql_cmd -f "$foods_down"
assert_after_foods
echo "official foods down again"
psql_cmd -f "$foods_down"
assert_after_foods
echo "rollback check finished"
