#!/usr/bin/env python3
"""Upsert official foods and aliases. Local and CI databases only.

Refuses any DATABASE_URL that points at Supabase. There is no flag that
overrides that refusal.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
from pathlib import Path

import psycopg

sys.path.insert(0, str(Path(__file__).resolve().parent))
from normalize import normalize_food_search_text

FOOD_UPDATE_COLUMNS = (
    "food_group",
    "index_no",
    "name",
    "display_name",
    "normalized_name",
    "reading",
    "base_amount",
    "unit_type",
    "refuse_pct",
    "kcal",
    "protein_g",
    "protein_aa_g",
    "fat_g",
    "fat_tag_g",
    "carb_g",
    "carb_avail_g",
    "fiber_g",
    "salt_eq_g",
    "raw_values",
    "estimated_fields",
    "source",
    "edition",
    "errata_version",
    "source_url",
)


def assert_not_production(url: str) -> None:
    lowered = url.lower()
    if (
        "supabase.co" in lowered
        or "supabase.com" in lowered
        or "supabase_" in lowered
    ):
        raise SystemExit(
            "refusing DATABASE_URL: it looks like hosted Supabase. "
            "This importer is for local Postgres and CI only."
        )


def _is_candidate(raw: str | None, note: str | None) -> bool:
    text = (raw or "").strip().lower()
    if text in ("true", "t", "1", "yes"):
        return True
    if text in ("false", "f", "0", "no"):
        return False
    return note is not None and "要確認" in note


def _blank(value: str | None) -> str | None:
    if value is None:
        return None
    text = value.strip()
    return text or None


def _number(value: str | None) -> float | None:
    text = _blank(value)
    if text is None:
        return None
    return float(text)


def _read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def food_payload(row: dict[str, str]) -> list:
    raw_values = json.loads(row["raw_values"]) if row.get("raw_values") else {}
    estimated = json.loads(row["estimated_fields"]) if row.get("estimated_fields") else []
    return [
        row["food_code"].strip(),
        _blank(row.get("food_group")),
        _blank(row.get("index_no")),
        row["name"],
        _blank(row.get("display_name")),
        row["normalized_name"].strip(),
        _blank(row.get("reading")),
        _number(row.get("base_amount")) if _blank(row.get("base_amount")) else 100,
        _blank(row.get("unit_type")) or "g",
        _number(row.get("refuse_pct")),
        _number(row.get("kcal")),
        _number(row.get("protein_g")),
        _number(row.get("protein_aa_g")),
        _number(row.get("fat_g")),
        _number(row.get("fat_tag_g")),
        _number(row.get("carb_g")),
        _number(row.get("carb_avail_g")),
        _number(row.get("fiber_g")),
        _number(row.get("salt_eq_g")),
        json.dumps(raw_values, ensure_ascii=False),
        estimated,
        _blank(row.get("source")) or "mext_sfct",
        _blank(row.get("edition")) or "八訂増補2023",
        _blank(row.get("errata_version")),
        _blank(row.get("source_url")),
    ]


def prepare_aliases(
    rows: list[dict[str, str]], present: set[str]
) -> tuple[list[dict], int]:
    prepared: list[dict] = []
    skipped = 0
    for row in rows:
        code = row["food_code"].strip()
        if code not in present:
            skipped += 1
            continue
        alias = row["alias"].strip()
        normalized = normalize_food_search_text(alias)
        if not normalized:
            skipped += 1
            continue
        priority_text = _blank(row.get("priority"))
        rank_text = _blank(row.get("candidate_rank"))
        note = _blank(row.get("note"))
        prepared.append(
            {
                "code": code,
                "alias": alias,
                "reading": _blank(row.get("reading")),
                "normalized": normalized,
                "priority": int(priority_text) if priority_text else 100,
                "note": note,
                "source": _blank(row.get("source")) or "karonavi_alias_v1",
                "is_candidate": _is_candidate(row.get("is_candidate"), note),
                "candidate_rank": int(rank_text) if rank_text else None,
            }
        )
    foods_for_alias: dict[str, set[str]] = {}
    for item in prepared:
        foods_for_alias.setdefault(item["normalized"], set()).add(item["code"])
    for item in prepared:
        if len(foods_for_alias[item["normalized"]]) > 1:
            item["is_candidate"] = True
    return prepared, skipped


def import_foods(connection: psycopg.Connection, rows: list[dict[str, str]]) -> int:
    columns = ("food_code",) + FOOD_UPDATE_COLUMNS
    assignments = ", ".join(
        f"{column} = excluded.{column}" for column in FOOD_UPDATE_COLUMNS
    )
    placeholders = []
    for column in columns:
        if column == "raw_values":
            placeholders.append("%s::jsonb")
        elif column == "estimated_fields":
            placeholders.append("%s::text[]")
        else:
            placeholders.append("%s")
    sql = f"""
        insert into public.official_foods ({", ".join(columns)}, imported_at)
        values ({", ".join(placeholders)}, now())
        on conflict (food_code) do update
        set {assignments}, imported_at = now()
    """
    with connection.cursor() as cursor:
        for row in rows:
            cursor.execute(sql, food_payload(row))
    return len(rows)


def import_aliases(connection: psycopg.Connection, rows: list[dict[str, str]]) -> tuple[int, int]:
    with connection.cursor() as cursor:
        cursor.execute("select food_code from public.official_foods")
        present = {code for (code,) in cursor.fetchall()}
        sql = """
            insert into public.official_food_aliases (
              food_code, alias, reading, normalized, priority, note, source,
              is_candidate, candidate_rank
            ) values (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            on conflict (food_code, normalized) do update
            set alias = excluded.alias,
                reading = excluded.reading,
                priority = excluded.priority,
                note = excluded.note,
                source = excluded.source,
                is_candidate = excluded.is_candidate,
                candidate_rank = excluded.candidate_rank
        """
        prepared, skipped = prepare_aliases(rows, present)
        for item in prepared:
            cursor.execute(
                sql,
                (
                    item["code"],
                    item["alias"],
                    item["reading"],
                    item["normalized"],
                    item["priority"],
                    item["note"],
                    item["source"],
                    item["is_candidate"],
                    item["candidate_rank"],
                ),
            )
        written = len(prepared)
    return written, skipped


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--foods", type=Path, required=True)
    parser.add_argument("--aliases", type=Path, required=True)
    parser.add_argument(
        "--database-url",
        default=os.environ.get("DATABASE_URL", ""),
        help="Defaults to DATABASE_URL. Hosted Supabase URLs are refused.",
    )
    args = parser.parse_args(argv)
    url = args.database_url.strip()
    if not url:
        raise SystemExit("DATABASE_URL is required")
    assert_not_production(url)

    foods = _read_csv(args.foods)
    aliases = _read_csv(args.aliases)
    with psycopg.connect(url) as connection:
        food_count = import_foods(connection, foods)
        alias_count, skipped = import_aliases(connection, aliases)
        connection.commit()
        with connection.cursor() as cursor:
            cursor.execute("select count(*) from public.official_foods")
            stored_foods = cursor.fetchone()[0]
            cursor.execute("select count(*) from public.official_food_aliases")
            stored_aliases = cursor.fetchone()[0]
    print(
        f"upserted foods={food_count} alias_rows={alias_count} "
        f"skipped_aliases={skipped} stored_foods={stored_foods} "
        f"stored_aliases={stored_aliases}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
