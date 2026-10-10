#!/usr/bin/env bash
# Applies migrations on a local Postgres and runs the banned-text pgTAP test.
# Does not connect to Supabase. Does not modify production.
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
failed=0
while IFS= read -r migration; do
  base="$(basename "$migration")"
  case "$base" in
    20261008090100_store_import_schedule.sql)
      if ! psql_cmd -tAc "select 1 from pg_available_extensions where name = 'pg_net'" | grep -q 1; then
        echo "skip $base (pg_net is not installed; notifications do not use it)"
        continue
      fi
      ;;
  esac
  echo "apply $migration"
  if ! psql_cmd -f "$migration"; then
    if [[ "$base" == 20261010045607_reject_banned_public_food_text.sql ]]; then
      echo "banned-text migration failed" >&2
      exit 1
    fi
    echo "warn: $base failed; continuing so the banned-text migration can still be applied" >&2
    failed=$((failed + 1))
  fi
done < <(find supabase/migrations -maxdepth 1 -name '*.sql' | sort)
echo "migrations with errors (not the banned-text migration): $failed"

echo "helpers"
psql_cmd -f supabase/tests/food_master_v1_1_test_helpers.sql

echo "pgtap"
tap_log="$(mktemp)"
psql_cmd -f supabase/tests/public_food_banned_text_test.sql | tee "$tap_log"
if grep -E 'not ok |Looks like you failed|Failed test' "$tap_log" >/dev/null; then
  echo "pgTAP reported failures" >&2
  exit 1
fi

echo "food-name corpus"
python3 - <<'PY' > /tmp/calonavi_food_names.tsv
import csv
from pathlib import Path

rows = []

def add(source, name):
    text = (name or "").strip()
    if text:
        rows.append((source, text.replace("\t", " ").replace("\n", " ")))

with Path("supabase/seed/official_foods_sample.csv").open(encoding="utf-8", newline="") as handle:
    for row in csv.DictReader(handle):
        add("sample.name", row.get("name"))
        add("sample.display_name", row.get("display_name"))

with Path("supabase/seed/official_food_aliases.csv").open(encoding="utf-8-sig", newline="") as handle:
    for row in csv.DictReader(handle):
        add("alias", row.get("alias"))
        add("alias.official_name", row.get("official_name"))

with Path("test/fixtures/official_food_display.tsv").open(encoding="utf-8") as handle:
    for line in handle:
        parts = line.rstrip("\n").split("\t")
        if len(parts) >= 3:
            add("display", parts[2])

recipe_sql = Path("supabase/seed/cook_recipes.sql").read_text(encoding="utf-8")
for label in __import__("re").findall(r"'([^']{1,80})'", recipe_sql):
    if any("\u3040" <= ch <= "\u9fff" or "\u30a0" <= ch <= "\u30ff" for ch in label):
        add("cook", label)

print(f"{len(rows)}")
for source, name in rows:
    print(f"{source}\t{name}")
PY

count="$(head -n 1 /tmp/calonavi_food_names.tsv)"
tail -n +2 /tmp/calonavi_food_names.tsv > /tmp/calonavi_food_names_body.tsv

psql_cmd <<SQL
drop table if exists ayg_test.food_name_corpus;
create table ayg_test.food_name_corpus (
  source text not null,
  name text not null
);
\copy ayg_test.food_name_corpus (source, name) from '/tmp/calonavi_food_names_body.tsv' with (format csv, delimiter E'\t')
SQL

flagged="$(psql_cmd -tAc "select count(*) from ayg_test.food_name_corpus where moderation.text_is_banned(name)")"
echo "corpus names: $count"
echo "corpus flagged: $flagged"
if [[ "$flagged" != "0" ]]; then
  psql_cmd -c "select source, name from ayg_test.food_name_corpus where moderation.text_is_banned(name) order by source, name"
  echo "food-name corpus contains a banned match" >&2
  exit 1
fi
psql_cmd -c "drop table if exists ayg_test.food_name_corpus;"

echo "banned-text tests ok"
