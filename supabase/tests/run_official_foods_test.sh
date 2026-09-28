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
from collections import defaultdict

foods_for_alias = defaultdict(set)
flagged = set()
with Path("supabase/seed/official_food_aliases.csv").open(encoding="utf-8-sig", newline="") as handle:
    for row in csv.DictReader(handle):
        got = normalize_food_search_text(row["alias"])
        if got != row["normalized"]:
            raise SystemExit(
                f"alias normalized mismatch {row['alias']!r}: csv={row['normalized']!r} got={got!r}"
            )
        foods_for_alias[row["normalized"]].add(row["food_code"])
        note = row.get("note") or ""
        marked = (row.get("is_candidate") or "").strip().lower() in ("true", "t", "1")
        if "要確認" in note or marked:
            flagged.add(row["normalized"])
for key in sorted(flagged):
    if len(foods_for_alias[key]) < 2:
        raise SystemExit(
            f"candidate alias {key} maps to one food {foods_for_alias[key]}"
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

python3 - <<'PY'
import hashlib
import sys
from pathlib import Path

sys.path.insert(0, "tool/official_foods")
from download import (
    DATA_WORKBOOK_SHA256,
    ERRATA_WORKBOOK_SHA256,
    MextRedirectHandler,
    MextUrlError,
    assert_mext_url,
    write_verified,
)

if DATA_WORKBOOK_SHA256 != (
    "0d5a77077dd6cd91cbc2e6e317b8b218a38728c409eed452f1c10635a0d3099c"
):
    raise SystemExit("chapter 2 sha256 pin changed")
if ERRATA_WORKBOOK_SHA256 != (
    "fb61037c7f66af0db1fb0729977913a629bc17097bc3ff7bf75217f9110acabb"
):
    raise SystemExit("errata sha256 pin changed")

allowed = "https://www.mext.go.jp/content/20260327-mxt_kagsei-mext-000029402_02.xlsx"
assert_mext_url(allowed)
rejected = [
    "http://www.mext.go.jp/a.xlsx",
    "https://fooddb.mext.go.jp/a.xlsx",
    "https://www.mext.go.jp.evil.example/a.xlsx",
    "https://user:pass@www.mext.go.jp/a.xlsx",
    "https://evil.example/a.xlsx",
    "https://www.mext.go.jp:8443/a.xlsx",
]
for url in rejected:
    try:
        assert_mext_url(url)
    except MextUrlError:
        pass
    else:
        raise SystemExit(f"allowed {url}")

handler = MextRedirectHandler()
try:
    handler.redirect_request(None, None, 302, "Found", {}, "https://evil.example/a.xlsx")
except MextUrlError:
    pass
else:
    raise SystemExit("redirect left www.mext.go.jp")

mismatch = Path("/tmp/official-foods-hash-mismatch.bin")
mismatch.write_bytes(b"not-the-workbook")
try:
    write_verified(b"not-the-workbook", mismatch, DATA_WORKBOOK_SHA256, "chapter 2 workbook")
except SystemExit as exc:
    if "sha256 mismatch" not in str(exc):
        raise
else:
    raise SystemExit("hash mismatch did not abort")
if mismatch.exists() or Path(str(mismatch) + ".partial").exists():
    raise SystemExit("hash mismatch left a file behind")

ok = Path("/tmp/official-foods-hash-ok.bin")
digest = hashlib.sha256(b"ok").hexdigest()
write_verified(b"ok", ok, digest, "fixture")
if ok.read_bytes() != b"ok":
    raise SystemExit("verified write failed")
ok.unlink()
ok.with_suffix(ok.suffix + ".sha256").unlink()
print("download host and sha256 checks ok")
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
if [[ "$(count_of "$second" stored_foods)" != "44" ]]; then
  echo "expected 44 stored foods" >&2
  exit 1
fi

echo "generate upsert sql"
sql_dir="/tmp/official-foods-sql"
rm -rf "$sql_dir"
python3 tool/official_foods/export_sql.py \
  --foods supabase/seed/official_foods_sample.csv \
  --aliases supabase/seed/official_food_aliases.csv \
  --out-dir "$sql_dir" \
  --batch-size 20
mapfile -t batches < <(find "$sql_dir" -name '*.sql' | sort)
if [[ "${#batches[@]}" -lt 2 ]]; then
  echo "expected foods and alias sql batches" >&2
  exit 1
fi
before_aliases="$(psql_cmd -tA -c 'select count(*) from public.official_food_aliases')"
for batch in "${batches[@]}"; do
  echo "apply $batch"
  if ! grep -q 'on conflict' "$batch"; then
    echo "batch is missing on conflict: $batch" >&2
    exit 1
  fi
  psql_cmd -f "$batch"
done
after_foods="$(psql_cmd -tA -c 'select count(*) from public.official_foods')"
after_aliases="$(psql_cmd -tA -c 'select count(*) from public.official_food_aliases')"
if [[ "$after_foods" != "44" || "$after_aliases" != "$before_aliases" ]]; then
  echo "generated sql changed counts foods=$after_foods aliases=$after_aliases (was $before_aliases)" >&2
  exit 1
fi

echo "search and privileges"
psql_cmd -f supabase/tests/official_foods_test.sql

echo "provenance columns"
psql_cmd -f supabase/tests/official_food_provenance_test.sql

echo "app upsert reproductions"
psql_cmd -f supabase/tests/food_master_v1_1_test_helpers.sql
psql_cmd -f supabase/tests/repro_upsert_regression.sql
psql_cmd -f supabase/tests/repro_softdelete.sql

echo "upsert delete race"
bash supabase/tests/repro_upsert_delete_race.sh

echo "reverse-order down stops"
reverse_status=0
reverse_out="$(psql_cmd -f supabase/rollback/20260928120000_official_foods_down.sql 2>&1)" || reverse_status=$?
if [[ "$reverse_status" -eq 0 ]]; then
  echo "official-foods down committed while provenance objects remain" >&2
  printf '%s\n' "$reverse_out" >&2
  exit 1
fi
if [[ "$reverse_out" != *20260928140000* ]]; then
  echo "reverse-order down did not tell the operator to run the provenance down" >&2
  printf '%s\n' "$reverse_out" >&2
  exit 1
fi
psql_cmd <<'SQL'
do $$
begin
  if to_regclass('public.official_foods') is null
     or to_regclass('public.official_food_aliases') is null
     or to_regprocedure('public.search_official_foods(text, integer)') is null
     or to_regprocedure('public.enforce_mext_saved_food_attribution()') is null
     or to_regprocedure('public.enforce_mext_food_entry_code()') is null then
    raise exception 'reverse-order down left triggers without official foods';
  end if;
  insert into public.food_entries (
    user_id, entry_id, name, quantity, logged_at, source_type
  ) values (
    '11111111-1111-1111-1111-111111111111',
    'manual-after-reverse-down',
    '手入力',
    1,
    timezone('utc', now()),
    'manual'
  );
end
$$;
SQL

echo "down provenance"
psql_cmd -f supabase/rollback/20260928140000_official_food_provenance_down.sql
psql_cmd <<'SQL'
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'saved_foods'
      and column_name in (
        'official_food_code', 'official_food_name', 'source_attribution'
      )
  ) or exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'food_entries'
      and column_name in ('official_food_code', 'official_food_name')
  ) or to_regprocedure('public.enforce_mext_saved_food_attribution()') is not null
    or to_regprocedure('public.enforce_mext_food_entry_code()') is not null then
    raise exception 'provenance down left columns or the attribution trigger';
  end if;
  if exists (
    select 1
    from pg_constraint
    where conname = 'food_entries_source_type_check'
      and pg_get_constraintdef(oid) ilike '%mext_sfct%'
  ) then
    raise exception 'food_entries source_type check still allows mext_sfct';
  end if;
  if exists (
    select 1
    from public.saved_foods
    where source_type = 'mext_sfct'
      and visibility = 'public'
  ) then
    raise exception 'provenance down left a composition-table food public';
  end if;
end
$$;
SQL

echo "down provenance again"
psql_cmd -f supabase/rollback/20260928140000_official_food_provenance_down.sql

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

echo "down migration again"
psql_cmd -f supabase/rollback/20260928120000_official_foods_down.sql

echo "official foods sql test ok"
