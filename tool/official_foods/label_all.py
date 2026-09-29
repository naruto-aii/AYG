#!/usr/bin/env python3
"""Build display names, readings, and aliases for every official food.

Reads tool/official_foods/data/official_food_names.tsv (a read-only export).
Does not connect to a database. Writes the migration, a spot-check, and counts.
"""

from __future__ import annotations

import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path

import pykakasi

sys.path.insert(0, str(Path(__file__).resolve().parent))
from label_draft import (
    GENERIC_ALIASES,
    TOKEN_READING,
    AliasDraft,
    DraftFood,
    Food,
    _KANJI,
    _katakana_to_hiragana,
    draft_display_name,
    review_aliases,
)
from normalize import normalize_food_search_text

ROOT = Path(__file__).resolve().parents[2]
NAMES = Path(__file__).resolve().parent / "data" / "official_food_names.tsv"
MIGRATION = ROOT / "supabase/migrations/20260929180000_official_food_labels.sql"
SPOT = ROOT / "docs/ops/official-food-label-spotcheck.md"

_KAKASI = pykakasi.kakasi()

# Applied before kakasi, longest first. These are compounds it reads wrong.
_PREPROCESS = (
    ("魚醤油", "ぎょしょうゆ"),
    ("乾パン", "かんぱん"),
    ("手延", "てのべ"),
    ("でん粉", "でんぷん"),
    ("充てん", "じゅうてん"),
    ("玄米粉", "げんまいこ"),
    ("米粉", "こめこ"),
    ("甘がき", "あまがき"),
    ("甘ぐり", "あまぐり"),
    ("甘みそ", "あまみそ"),
    ("甘辛", "あまから"),
    ("乳飲料", "にゅういんりょう"),
    ("加工乳", "かこうにゅう"),
    ("脱脂乳", "だっしにゅう"),
    ("やぎ乳", "やぎにゅう"),
    ("人乳", "じんにゅう"),
    ("乳成分", "にゅうせいぶん"),
    ("日本", "にほん"),
)

# 米 stays こめ / べい in these words. Everywhere else in a token it is まい.
_KOME_KEEP = ("米国", "米菓", "そば米", "米ぬか", "米こうじ", "米みそ", "米酢", "米粒")


@dataclass(frozen=True)
class GroupAlias:
    food_code: str
    alias: str
    reading: str
    note: str


def load_foods() -> list[Food]:
    foods: list[Food] = []
    for line in NAMES.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        food_code, food_group, name = line.split("\t", 2)
        foods.append(Food(food_code, food_group, name))
    return foods


def _preprocess(token: str) -> str:
    for source, target in _PREPROCESS:
        token = token.replace(source, target)
    if (
        token.startswith("生")
        and len(token) > 1
        and "\u3041" <= token[1] <= "\u3096"
    ):
        token = "なま" + token[1:]
    if "米" in token and not any(word in token for word in _KOME_KEEP):
        if "こめこ" not in token and "げんまいこ" not in token:
            token = token.replace("米", "まい")
    if (
        "粉" in token
        and not token.startswith("粉")
        and "粉末" not in token
        and "粉乳" not in token
        and "粉糖" not in token
        and "精粉" not in token
        and "でんぷん" not in token
    ):
        token = token.replace("粉", "こ")
    # 漬 without け is づけ (奈良漬). 漬物 and 漬け already include the reading.
    if "漬" in token:
        protected = token.replace("漬物", "\u0000").replace("漬け", "\u0001")
        protected = protected.replace("漬", "づけ")
        token = protected.replace("\u0000", "漬物").replace("\u0001", "漬け")
    return token


def _is_hiragana(text: str) -> bool:
    return bool(text) and all("\u3041" <= char <= "\u3096" for char in text)


def _join_kakasi(parts: list[dict[str, str]]) -> str:
    """Drop okurigana kakasi already folded into the previous kanji.

    煮干 + しだし is read にぼし + しだし. The し belongs to the next
    chunk, so the joined reading is にぼしだし. A written kana that is
    already inside the previous chunk (蒸し + しゃぶ) is left alone.
    """
    chunks: list[str] = []
    for index, part in enumerate(parts):
        reading = part["hira"]
        if index + 1 < len(parts):
            nxt = parts[index + 1]["orig"]
            overlap = 0
            for size in range(min(len(reading), len(nxt)), 0, -1):
                piece = nxt[:size]
                if (
                    _is_hiragana(piece)
                    and reading.endswith(piece)
                    and not part["orig"].endswith(piece)
                ):
                    overlap = size
                    break
            if overlap:
                reading = reading[:-overlap]
        chunks.append(reading)
    return "".join(chunks)


def token_reading_any(token: str) -> str:
    if token in TOKEN_READING:
        return TOKEN_READING[token]
    if not _KANJI.search(token):
        return _katakana_to_hiragana(token)
    prepared = _preprocess(token)
    if not _KANJI.search(prepared):
        return _katakana_to_hiragana(prepared)
    reading = _join_kakasi(_KAKASI.convert(prepared))
    if _KANJI.search(reading) or not reading:
        raise KeyError(f"no hiragana reading for token {token!r}")
    return reading


def reading_of(display_name: str) -> str:
    bare = display_name.replace("（", " ").replace("）", " ").replace("・", " ")
    parts = [token_reading_any(token) for token in bare.split() if token]
    return " ".join(parts)


def draft_foods(foods: list[Food]) -> list[DraftFood]:
    drafted: list[DraftFood] = []
    for food in foods:
        display = draft_display_name(food.name)
        reading = reading_of(display)
        drafted.append(
            DraftFood(
                food=food,
                display_name=display,
                reading=reading,
                search_reading=normalize_food_search_text(reading),
            )
        )
    return drafted


def _head_aliases(foods: list[DraftFood]) -> list[AliasDraft]:
    proposed: list[AliasDraft] = []
    for food in foods:
        head = food.display_name.split("（", 1)[0].strip()
        texts = [head]
        if " " in head:
            texts.append(head.replace(" ", ""))
        if head.startswith("若鶏") and len(head) > 2:
            texts.append("鶏" + head[2:])
        official = normalize_food_search_text(food.food.name)
        seen: set[str] = set()
        for text in texts:
            key = normalize_food_search_text(text)
            if not key or key in seen or len(key) < 2:
                continue
            if text in GENERIC_ALIASES or key in {
                normalize_food_search_text(word) for word in GENERIC_ALIASES
            }:
                continue
            # Already found by the official name. Leave that match as it is.
            if key in official:
                continue
            seen.add(key)
            proposed.append(
                AliasDraft(
                    food_code=food.food.food_code,
                    alias=text,
                    reading=reading_of(text),
                )
            )

    grouped: dict[str, list[AliasDraft]] = defaultdict(list)
    for draft in proposed:
        grouped[normalize_food_search_text(draft.alias)].append(draft)
    shared: list[AliasDraft] = []
    for drafts in grouped.values():
        codes = []
        for draft in drafts:
            if draft.food_code not in codes:
                codes.append(draft.food_code)
        many = len(codes) > 1
        for rank, food_code in enumerate(codes, start=1):
            draft = next(item for item in drafts if item.food_code == food_code)
            shared.append(
                AliasDraft(
                    food_code=food_code,
                    alias=draft.alias,
                    reading=draft.reading,
                    is_candidate=many,
                    candidate_rank=rank if many else None,
                    note="同じ呼び方が複数の食品にある" if many else "",
                )
            )
    return shared


def _is_beef(food: Food) -> bool:
    return food.food_group == "11" and "うし" in food.name


def _is_pork(food: Food) -> bool:
    return food.food_group == "11" and "ぶた" in food.name


def _is_chicken(food: Food) -> bool:
    return food.food_group == "11" and "にわとり" in food.name


def _is_meat(food: Food) -> bool:
    return food.food_group == "11"


def _is_fish(food: Food) -> bool:
    return food.food_group == "10" and "＜魚類＞" in food.name


_GROUP_TERMS = (
    (_is_beef, (("牛肉", "ぎゅうにく"), ("ビーフ", "びーふ"), ("牛", "ぎゅう"))),
    (_is_pork, (("豚肉", "ぶたにく"), ("ポーク", "ぽーく"), ("豚", "ぶた"))),
    (_is_chicken, (("鶏肉", "とりにく"), ("チキン", "ちきん"), ("鶏", "とり"))),
    (_is_meat, (("肉", "にく"),)),
    (_is_fish, (("魚", "さかな"),)),
)


def group_aliases(foods: list[Food]) -> list[GroupAlias]:
    rows: list[GroupAlias] = []
    for predicate, terms in _GROUP_TERMS:
        members = [food for food in foods if predicate(food)]
        for alias, reading in terms:
            for food in members:
                rows.append(
                    GroupAlias(
                        food_code=food.food_code,
                        alias=alias,
                        reading=reading,
                        note="グループ語。当てはまる食品をすべて候補にする",
                    )
                )
    return rows


def sql_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def write_migration(
    foods: list[DraftFood],
    aliases: list[AliasDraft],
    groups: list[GroupAlias],
) -> None:
    search = _patched_search_function()
    lines = [
        "-- Display names, hiragana readings, and group-term aliases.",
        "-- Backup tables keep the previous display_name and reading, and",
        "-- every alias row, so the label update can be reversed without",
        "-- deleting meal logs. Existing karonavi_alias_v1 rows are not",
        "-- updated: inserts conflict on (food_code, normalized) and skip.",
        "-- On an empty table (CI, before the sample import) the data",
        "-- statements match nothing.",
        "",
        "create table if not exists public.official_foods_label_backup_20260929 as",
        "select food_code, display_name, reading",
        "from public.official_foods;",
        "",
        "create table if not exists public.official_food_aliases_backup_20260929 as",
        "select *",
        "from public.official_food_aliases;",
        "",
        "alter table public.official_foods_label_backup_20260929 enable row level security;",
        "alter table public.official_food_aliases_backup_20260929 enable row level security;",
        "revoke all on table public.official_foods_label_backup_20260929 from public, anon, authenticated;",
        "revoke all on table public.official_food_aliases_backup_20260929 from public, anon, authenticated;",
        "",
        "alter table public.official_foods",
        "  add column if not exists normalized_reading text;",
        "",
        "alter table public.official_food_aliases",
        "  add column if not exists normalized_reading text;",
        "",
        "alter table public.official_food_aliases",
        "  add column if not exists is_group boolean not null default false;",
        "",
        "comment on column public.official_food_aliases.is_group is",
        "  'Wide words such as 牛肉. Every matching food is a candidate.';",
        "",
        "create or replace function public.official_foods_fill_normalized_reading()",
        "returns trigger",
        "language plpgsql",
        "set search_path = ''",
        "as $$",
        "begin",
        "  if tg_table_name = 'official_foods' then",
        "    new.normalized_reading := public.normalize_food_search_text(new.reading);",
        "  else",
        "    new.normalized_reading := public.normalize_food_search_text(coalesce(new.reading, new.alias));",
        "  end if;",
        "  return new;",
        "end;",
        "$$;",
        "",
        "revoke all on function public.official_foods_fill_normalized_reading() from public, anon, authenticated;",
        "",
        "drop trigger if exists official_foods_fill_normalized_reading on public.official_foods;",
        "create trigger official_foods_fill_normalized_reading",
        "  before insert or update of reading on public.official_foods",
        "  for each row",
        "  execute function public.official_foods_fill_normalized_reading();",
        "",
        "drop trigger if exists official_food_aliases_fill_normalized_reading on public.official_food_aliases;",
        "create trigger official_food_aliases_fill_normalized_reading",
        "  before insert or update of reading, alias on public.official_food_aliases",
        "  for each row",
        "  execute function public.official_foods_fill_normalized_reading();",
        "",
        "do $$",
        "declare",
        "  opschema text;",
        "begin",
        "  select n.nspname into opschema",
        "  from pg_opclass c",
        "  join pg_namespace n on n.oid = c.opcnamespace",
        "  where c.opcname = 'gin_trgm_ops'",
        "  order by case when n.nspname = 'extensions' then 0 else 1 end",
        "  limit 1;",
        "  if opschema is null then",
        "    raise exception 'gin_trgm_ops is missing';",
        "  end if;",
        "  if not exists (",
        "    select 1 from pg_indexes",
        "    where schemaname = 'public'",
        "      and indexname = 'official_foods_normalized_reading_trgm_idx'",
        "  ) then",
        "    execute format(",
        "      'create index official_foods_normalized_reading_trgm_idx on public.official_foods using gin (normalized_reading %I.gin_trgm_ops)',",
        "      opschema",
        "    );",
        "  end if;",
        "  if not exists (",
        "    select 1 from pg_indexes",
        "    where schemaname = 'public'",
        "      and indexname = 'official_food_aliases_normalized_reading_trgm_idx'",
        "  ) then",
        "    execute format(",
        "      'create index official_food_aliases_normalized_reading_trgm_idx on public.official_food_aliases using gin (normalized_reading %I.gin_trgm_ops)',",
        "      opschema",
        "    );",
        "  end if;",
        "end",
        "$$;",
        "",
        "create index if not exists official_food_aliases_group_term_idx",
        "  on public.official_food_aliases (normalized, normalized_reading)",
        "  where is_group;",
        "",
        search,
        "",
    ]

    food_values = []
    for food in foods:
        food_values.append(
            "("
            + ", ".join(
                (
                    sql_literal(food.food.food_code),
                    sql_literal(food.display_name),
                    sql_literal(food.reading),
                )
            )
            + ")"
        )
    lines.append("update public.official_foods as food")
    lines.append("set display_name = incoming.display_name,")
    lines.append("    reading = incoming.reading")
    lines.append("from (values")
    lines.append(",\n".join(food_values))
    lines.append(") as incoming(food_code, display_name, reading)")
    lines.append("where food.food_code = incoming.food_code;")
    lines.append("")

    alias_rows = []
    seen_keys: set[tuple[str, str]] = set()
    for alias in aliases:
        key = (alias.food_code, normalize_food_search_text(alias.alias))
        if key in seen_keys:
            continue
        seen_keys.add(key)
        rank = "null" if alias.candidate_rank is None else str(alias.candidate_rank)
        alias_rows.append(
            "("
            + ", ".join(
                (
                    sql_literal(alias.food_code),
                    sql_literal(alias.alias),
                    sql_literal(alias.reading),
                    sql_literal(normalize_food_search_text(alias.alias)),
                    "true" if alias.is_candidate else "false",
                    rank,
                    sql_literal(alias.note),
                    "false",
                )
            )
            + ")"
        )
    for alias in groups:
        key = (alias.food_code, normalize_food_search_text(alias.alias))
        if key in seen_keys:
            continue
        seen_keys.add(key)
        alias_rows.append(
            "("
            + ", ".join(
                (
                    sql_literal(alias.food_code),
                    sql_literal(alias.alias),
                    sql_literal(alias.reading),
                    sql_literal(normalize_food_search_text(alias.alias)),
                    "true",
                    "null",
                    sql_literal(alias.note),
                    "true",
                )
            )
            + ")"
        )

    lines.append("insert into public.official_food_aliases (")
    lines.append("  food_code, alias, reading, normalized, is_candidate,")
    lines.append("  candidate_rank, note, source, is_group")
    lines.append(")")
    lines.append("select")
    lines.append("  incoming.food_code,")
    lines.append("  incoming.alias,")
    lines.append("  incoming.reading,")
    lines.append("  incoming.normalized,")
    lines.append("  incoming.is_candidate,")
    lines.append("  incoming.candidate_rank,")
    lines.append("  incoming.note,")
    lines.append("  'label_draft_v1',")
    lines.append("  incoming.is_group")
    lines.append("from (values")
    lines.append(",\n".join(alias_rows))
    lines.append(") as incoming(")
    lines.append("  food_code, alias, reading, normalized, is_candidate,")
    lines.append("  candidate_rank, note, is_group")
    lines.append(")")
    lines.append("where exists (")
    lines.append("  select 1 from public.official_foods as food")
    lines.append("  where food.food_code = incoming.food_code")
    lines.append(")")
    lines.append("on conflict (food_code, normalized) do nothing;")
    lines.append("")
    lines.append("update public.official_foods")
    lines.append("set normalized_reading = public.normalize_food_search_text(reading)")
    lines.append("where normalized_reading is null;")
    lines.append("")
    lines.append("update public.official_food_aliases")
    lines.append("set normalized_reading = public.normalize_food_search_text(coalesce(reading, alias))")
    lines.append("where normalized_reading is null;")
    lines.append("")
    MIGRATION.write_text("\n".join(lines), encoding="utf-8")


def _patched_search_function() -> str:
    source = (ROOT / "supabase/migrations/20260928120000_official_foods.sql").read_text(
        encoding="utf-8"
    )
    start = source.index("create or replace function public.search_official_foods(")
    end = source.index("\nalter table public.official_foods enable row level security;")
    function = source[start:end].rstrip() + "\n"
    function = function.replace(
        "  if v_query = '' or v_limit = 0 then\n    return;\n  end if;\n",
        "  if v_query = '' or v_limit = 0 then\n"
        "    return;\n"
        "  end if;\n"
        "\n"
        "  -- Group words (牛肉, 肉, 魚, チキン, …) return every member.\n"
        "  -- The client asks for 30, which would hide the rest.\n"
        "  if exists (\n"
        "    select 1\n"
        "    from public.official_food_aliases as group_alias\n"
        "    where group_alias.is_group\n"
        "      and (\n"
        "        group_alias.normalized = v_query\n"
        "        or group_alias.normalized_reading = v_query\n"
        "      )\n"
        "  ) then\n"
        "    v_limit := 800;\n"
        "  end if;\n",
    )
    for column in ("f.reading", "a.reading"):
        function = function.replace(
            f"strpos({column},",
            f"strpos({column.split('.')[0]}.normalized_reading,",
        )
        function = function.replace(
            f"when {column} =",
            f"when {column.split('.')[0]}.normalized_reading =",
        )
        function = function.replace(
            f"where {column} like",
            f"where {column.split('.')[0]}.normalized_reading like",
        )
    function = function.replace(
        "-- aliases.normalized are already the search key. reading is stored text\n"
        "  -- (hiragana in the alias dictionary) and is compared as stored.",
        "-- aliases.normalized are already the search key. Human reading keeps\n"
        "  -- the long vowel. normalized_reading is the search key.",
    )
    return function


def write_spotcheck(
    foods: list[DraftFood],
    accepted: dict[str, list[AliasDraft]],
    groups: list[GroupAlias],
    rejected_count: int,
) -> None:
    by_group: dict[str, list[DraftFood]] = defaultdict(list)
    for food in foods:
        by_group[food.food.food_group].append(food)
    group_by_code: dict[str, list[str]] = defaultdict(list)
    for alias in groups:
        if alias.alias not in group_by_code[alias.food_code]:
            group_by_code[alias.food_code].append(alias.alias)
    lines = [
        "# 全件ラベルの抜き取り",
        "",
        f"食品 {len(foods)} 件。別名の規則で落とした下書きは {rejected_count} 件。",
        "各食品群から先頭と中ほどを出した。肉類は紛らわしい部位を足している。",
        "",
    ]
    meat_codes = {
        "11001",
        "11015",
        "11016",
        "11029",
        "11043",
        "11059",
        "11071",
        "11085",
        "11123",
        "11140",
        "11220",
        "11224",
        "11227",
        "11288",
    }
    for group in sorted(by_group):
        rows = by_group[group]
        picks = [rows[0], rows[len(rows) // 2]]
        if group == "11":
            extra = [row for row in rows if row.food.food_code in meat_codes]
            picks = extra
        lines.append(f"## {group}")
        lines.append("")
        lines.append("| 食品番号 | 正式名称 | display_name | 読み | 別名 |")
        lines.append("| --- | --- | --- | --- | --- |")
        seen: set[str] = set()
        for row in picks:
            if row.food.food_code in seen:
                continue
            seen.add(row.food.food_code)
            names = [item.alias for item in accepted.get(row.food.food_code, [])]
            names.extend(group_by_code.get(row.food.food_code, []))
            official = " ".join(row.food.name.split())
            alias_text = " / ".join(names) if names else "（なし）"
            lines.append(
                f"| {row.food.food_code} | {official} | {row.display_name} | {row.reading} | {alias_text} |"
            )
        lines.append("")
    SPOT.write_text("\n".join(lines), encoding="utf-8")


def build() -> tuple[list[DraftFood], list[AliasDraft], list[AliasDraft], list[GroupAlias]]:
    foods = draft_foods(load_foods())
    accepted, rejected = review_aliases(foods, _head_aliases(foods))
    return foods, accepted, rejected, group_aliases([food.food for food in foods])


def main() -> None:
    foods, accepted, rejected, groups = build()
    by_code: dict[str, list[AliasDraft]] = defaultdict(list)
    for alias in accepted:
        by_code[alias.food_code].append(alias)
    write_migration(foods, accepted, groups)
    write_spotcheck(foods, by_code, groups, len(rejected))
    print(
        f"foods {len(foods)} aliases {len(accepted)} "
        f"rejected {len(rejected)} groups {len(groups)}"
    )


if __name__ == "__main__":
    main()
