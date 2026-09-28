#!/usr/bin/env bash
# Postgres check for the official-foods migration.
# Applies every migration on this branch, imports the sample twice, checks
# search, then applies the down script. Does not connect to Supabase.
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

psql_cmd() {
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 "$@"
}

echo "bootstrap"
psql_cmd -f supabase/tests/official_foods_pg_bootstrap.sql

echo "migrations"
while IFS= read -r migration; do
  echo "apply $migration"
  psql_cmd -f "$migration"
done < <(find supabase/migrations -maxdepth 1 -name '*.sql' | sort)

python3 - <<'PY'
import csv
import sys
from pathlib import Path

sys.path.insert(0, "tool/official_foods")
from normalize import assert_shared_cases, normalize_food_search_text

assert_shared_cases()
with Path("supabase/seed/official_food_aliases.csv").open(encoding="utf-8-sig", newline="") as handle:
    for row in csv.DictReader(handle):
        got = normalize_food_search_text(row["alias"])
        if got != row["normalized"]:
            raise SystemExit(
                f"alias normalized mismatch {row['alias']!r}: csv={row['normalized']!r} got={got!r}"
            )
with Path("supabase/seed/official_foods_sample.csv").open(encoding="utf-8", newline="") as handle:
    foods = {row["food_code"]: row for row in csv.DictReader(handle)}
rice = foods["01088"]
if rice["kcal"] != "156":
    raise SystemExit(f"01088 kcal is {rice['kcal']!r}, expected 156")
if "ENERC_KCAL" not in rice["raw_values"] or "NACL_EQ" not in rice["raw_values"]:
    raise SystemExit("sample raw_values dropped underscore component ids")
print("python normalizer and sample checks ok")
PY

echo "production URL is refused"
set +e
DATABASE_URL="postgresql://postgres:ci@db.example.supabase.co:5432/postgres" \
  python3 tool/official_foods/import.py \
    --foods supabase/seed/official_foods_sample.csv \
    --aliases supabase/seed/official_food_aliases.csv
refused=$?
set -e
if [[ "$refused" -eq 0 ]]; then
  echo "import.py accepted a Supabase URL" >&2
  exit 1
fi

import_once() {
  DATABASE_URL="$DATABASE_URL" python3 tool/official_foods/import.py \
    --foods supabase/seed/official_foods_sample.csv \
    --aliases supabase/seed/official_food_aliases.csv
}

echo "import 1"
first="$(import_once)"
echo "$first"
echo "import 2"
second="$(import_once)"
echo "$second"
count_of() {
  python3 - "$1" "$2" <<'PY'
import sys
text, key = sys.argv[1], sys.argv[2]
for part in text.split():
    if part.startswith(key + "="):
        print(part.split("=", 1)[1])
        break
else:
    raise SystemExit(f"missing {key} in {text}")
PY
}
for key in stored_foods stored_aliases; do
  a="$(count_of "$first" "$key")"
  b="$(count_of "$second" "$key")"
  if [[ "$a" != "$b" ]]; then
    echo "$key changed on the second import: $a -> $b" >&2
    exit 1
  fi
done
if [[ "$(count_of "$second" stored_foods)" != "40" ]]; then
  echo "expected 40 stored foods" >&2
  exit 1
fi

echo "search and privileges"
psql_cmd -f supabase/tests/official_foods_test.sql

echo "down migration"
psql_cmd -f supabase/rollback/20260928120000_official_foods_down.sql
psql_cmd <<'SQL'
do $$
begin
  if to_regclass('public.official_foods') is not null
     or to_regclass('public.official_food_aliases') is not null
     or to_regprocedure('public.search_official_foods(text, integer)') is not null
     or to_regprocedure('public.normalize_food_search_text(text)') is not null then
    raise exception 'down migration left official-foods objects behind';
  end if;
  if not exists (select 1 from pg_extension where extname = 'pg_trgm') then
    raise exception 'down migration dropped pg_trgm';
  end if;
  if exists (
    select 1
    from pg_constraint
    where conname = 'saved_foods_source_type_check'
      and pg_get_constraintdef(oid) ilike '%mext_sfct%'
  ) then
    raise exception 'source_type check still allows mext_sfct';
  end if;
end
$$;
SQL

echo "official foods sql test ok"
