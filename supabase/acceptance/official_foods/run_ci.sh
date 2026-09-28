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
  if [[ "$base" == "20260928120000_official_foods.sql" ]]; then
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

official="$FEATURE_DIR/supabase/migrations/20260928120000_official_foods.sql"
echo "apply official foods migration"
psql_cmd -f "$official"

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
