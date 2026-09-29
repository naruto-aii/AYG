#!/usr/bin/env python3
"""Draft display names, hiragana readings, and aliases for a 50-food sample.

This does not connect to a database. The 50 official names were copied from a
read-only look at public.official_foods. Stage 1 stops at the sample files.
"""

from __future__ import annotations

import csv
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from normalize import normalize_food_search_text

GROUP_LABELS = {
    "01": "穀類",
    "02": "いも及びでん粉類",
    "03": "砂糖及び甘味類",
    "04": "豆類",
    "05": "種実類",
    "06": "野菜類",
    "07": "果実類",
    "08": "きのこ類",
    "09": "藻類",
    "10": "魚介類",
    "11": "肉類",
    "12": "卵類",
    "13": "乳類",
    "14": "油脂類",
    "15": "菓子類",
    "16": "し好飲料類",
    "17": "調味料及び香辛料類",
    "18": "調理済み流通食品類",
}

# Tokens that name a shelf, not the food.
DROP_TOKENS = {
    "塊茎",
    "塊根",
    "球茎",
    "結球葉",
    "果実",
    "花らい",
    "茎葉",
    "根茎",
    "葉柄",
    "花序",
    "洋風料理",
    "和風料理",
    "中国料理",
    "韓国料理",
    "カレー類",
    "煮物類",
    "菜類",
    "汁物類",
    "半固体状ドレッシング",
    "こめ",
    "こむぎ",
    "だいず",
}

# Shelf words are omitted when the food itself is still in the name.
# If nothing else remains, they become the title.
SHELF_LABEL = {
    "こめ": "米",
    "こむぎ": "小麦",
    "だいず": "大豆",
}

# Parentheses that name a shelf, not a preparation note.
DROP_PAREN = {"その他"}

DROP_VARIETIES = {
    "パン類",
    "中華めん類",
    "豆腐・油揚げ類",
    "納豆類",
    "即席めん類",
    "その他",
}

PREFIX_VARIETY = {
    "和牛肉": "和牛",
    "乳用肥育牛肉": "乳用肥育牛",
    "輸入牛肉": "輸入牛",
}

PAREN_VARIETY = {
    "水稲めし": "水稲めし",
    "大型種肉": "大型種",
}

HEAD_VARIETY = {
    "若どり・主品目": "若鶏",
    "若どり・副品目": "若鶏",
}

SPECIES_PREFIX = {
    "ぶた": "豚",
    "いのしし": "いのしし",
}

# Spoken qualifiers. They move into the parenthesis, in this order.
QUALIFIER_ORDER = [
    "うるち米",
    "もち米",
    "全粒",
    "皮なし",
    "皮つき",
    "脂身つき",
    "皮下脂肪なし",
    "赤肉",
    "赤身",
    "養殖",
    "天然",
    "国産品",
    "全脂無糖",
    "全卵型",
    "全卵",
    "こしあん入り",
    "浸出液",
    "素干し",
    "生",
    "ゆで",
    "焼き",
    "乾",
    "水煮",
    "油いため",
    "缶詰",
    "冷凍",
    "漬物",
    "塩漬",
    "油揚げ",
    "非油揚げ",
    "味付け",
    "蒸し",
    "開き干し",
    "塩蔵",
    "塩抜き",
    "電子レンジ調理",
    "水戻し",
    "素揚げ",
    "天ぷら",
    "つくだ煮",
    "砂じょう",
    "果汁",
    "果実飲料",
    "ジャム",
    "高糖度",
    "低糖度",
    "早生",
    "普通",
    "完熟",
    "未熟",
    "国産",
    "米国産",
    "中国産",
    "輸入",
    "菌床栽培",
    "原木栽培",
    "水煮缶詰",
    "ストレートジュース",
    "濃縮還元ジュース",
    "果粒入りジュース",
]

QUALIFIER_LABEL = {
    "うるち米": "うるち米",
    "もち米": "もち米",
    "国産品": "国産",
    "こしあん入り": "こしあん",
}

# Kanji and katakana tokens that the sample actually uses. Unknown kanji
# fails the draft instead of being copied through as a fake reading.
TOKEN_READING = {
    "生": "なま",
    "ゆで": "ゆで",
    "焼き": "やき",
    "乾": "かん",
    "素干し": "すぼし",
    "脂身つき": "あぶらみつき",
    "皮下脂肪なし": "ひかしぼうなし",
    "赤肉": "あかにく",
    "赤身": "あかみ",
    "皮なし": "かわなし",
    "皮つき": "かわつき",
    "全粒": "ぜんりゅう",
    "国産品": "こくさん",
    "国産": "こくさん",
    "養殖": "ようしょく",
    "天然": "てんねん",
    "浸出液": "しんしゅつえき",
    "全脂無糖": "ぜんしむとう",
    "全卵型": "ぜんらんがた",
    "全卵": "ぜんらん",
    "こしあん入り": "こしあん",
    "こしあん": "こしあん",
    "うるち米": "うるちまい",
    "もち米": "もちごめ",
    "精白米": "せいはくまい",
    "玄米": "げんまい",
    "はいが精米": "はいがせいまい",
    "角形食パン": "かくがたしょくぱん",
    "食パン": "しょくぱん",
    "中華めん": "ちゅうかめん",
    "じゃがいも": "じゃがいも",
    "黒砂糖": "くろざとう",
    "はちみつ": "はちみつ",
    "あずき": "あずき",
    "木綿豆腐": "もめんどうふ",
    "糸引き納豆": "いとひきなっとう",
    "アーモンド": "あーもんど",
    "キャベツ": "きゃべつ",
    "赤色トマト": "あかいろとまと",
    "いちご": "いちご",
    "バナナ": "ばなな",
    "えのきたけ": "えのきたけ",
    "あおさ": "あおさ",
    "まあじ": "まあじ",
    "しろさけ": "しろさけ",
    "たいせいようさけ": "たいせいようさけ",
    "くろまぐろ": "くろまぐろ",
    "いのしし": "いのしし",
    "いのしし肉": "いのししにく",
    "肉": "にく",
    "若鶏むね": "わかどりむね",
    "若鶏もも": "わかどりもも",
    "若鶏ささみ": "わかどりささみ",
    "豚ロース": "ぶたろーす",
    "豚ヒレ": "ぶたひれ",
    "和牛": "わぎゅう",
    "乳用肥育牛": "にゅうようひいくぎゅう",
    "輸入牛": "ゆにゅうぎゅう",
    "大型種": "おおがたしゅ",
    "若鶏": "わかどり",
    "サーロイン": "さーろいん",
    "ヒレ": "ひれ",
    "ロース": "ろーす",
    "むね": "むね",
    "もも": "もも",
    "ささみ": "ささみ",
    "豚": "ぶた",
    "鶏卵": "けいらん",
    "普通牛乳": "ふつうぎゅうにゅう",
    "ヨーグルト": "よーぐると",
    "オリーブ油": "おりーぶゆ",
    "無発酵": "むはっこう",
    "有塩バター": "ゆうえんばたー",
    "大福もち": "だいふくもち",
    "せん茶": "せんちゃ",
    "コーヒー": "こーひー",
    "ウスターソース": "うすたーそーす",
    "マヨネーズ": "まよねーず",
    "ビーフカレー": "びーふかれー",
    "牛飯の具": "ぎゅうめしのぐ",
    "チャーハン": "ちゃーはん",
    "水稲めし": "すいとうめし",
}

PART_WORDS = (
    "サーロイン",
    "ヒレ",
    "ロース",
    "ばら",
    "かた",
    "もも",
    "むね",
    "ささみ",
    "赤身",
    "脂身",
)

GENERIC_ALIASES = {
    "肉",
    "魚",
    "牛",
    "豚",
    "鶏",
    "野菜",
    "牛肉",
    "豚肉",
    "鶏肉",
    "ビーフ",
    "ポーク",
    "チキン",
}

_SPLIT = re.compile(r"[ \u3000]+")
_BRACKET = re.compile(r"^［(.+)］$")
_ANGLE = re.compile(r"^＜(.+)＞$")
_PAREN = re.compile(r"^（(.+)）$")
_KANJI = re.compile(r"[\u4e00-\u9fff]")


@dataclass(frozen=True)
class Food:
    food_code: str
    food_group: str
    name: str


@dataclass(frozen=True)
class AliasDraft:
    food_code: str
    alias: str
    reading: str
    is_candidate: bool = False
    candidate_rank: int | None = None
    note: str = ""


@dataclass
class DraftFood:
    food: Food
    display_name: str
    reading: str
    search_reading: str
    aliases: list[AliasDraft] = field(default_factory=list)


@dataclass(frozen=True)
class RejectedAlias:
    draft: AliasDraft
    reason: str


def _tokens(name: str) -> list[str]:
    return [token for token in _SPLIT.split(name.strip()) if token]


def draft_display_name(name: str) -> str:
    """Short list label. The official name stays unchanged for the detail view."""
    variety = ""
    body: list[str] = []
    shelf: list[str] = []
    notes: list[str] = []
    for token in _tokens(name):
        bracket = _BRACKET.match(token)
        if bracket:
            variety = bracket.group(1)
            continue
        if _ANGLE.match(token):
            continue
        paren = _PAREN.match(token)
        if paren:
            inner = paren.group(1)
            # 「発酵乳・乳酸菌飲料」のような棚の名前は落とす。
            # 「添付調味料等を含むもの」のような条件は残す。
            if "・" in inner or inner.endswith("類") or inner in DROP_PAREN:
                continue
            notes.append(inner)
            continue
        if token in DROP_TOKENS:
            shelf.append(token)
            continue
        body.append(token)

    prefix = ""
    qualifiers: list[str] = []
    if variety in PREFIX_VARIETY:
        prefix = PREFIX_VARIETY[variety]
        body = [token for token in body if token != "うし"]
    elif variety in PAREN_VARIETY:
        qualifiers.append(PAREN_VARIETY[variety])
    elif variety in HEAD_VARIETY:
        prefix = HEAD_VARIETY[variety]
        body = [token for token in body if token != "にわとり"]
    elif variety.endswith("類") or variety in DROP_VARIETIES:
        pass
    elif variety:
        qualifiers.append(variety)

    if body and body[0] in SPECIES_PREFIX and (prefix or len(body) > 1):
        species = SPECIES_PREFIX[body.pop(0)]
        if species == "豚":
            prefix = species
        elif not prefix:
            prefix = species

    collapsed: list[str] = []
    for token in body:
        if collapsed and (token == collapsed[-1] or token in collapsed[-1]):
            continue
        if token == "無発酵バター":
            qualifiers.append("無発酵")
            token = "有塩バター" if "有塩" in name else token
        collapsed.append(token)

    head: list[str] = []
    for token in collapsed:
        if token in QUALIFIER_ORDER or token in QUALIFIER_LABEL:
            qualifiers.append(QUALIFIER_LABEL.get(token, token))
        else:
            head.append(token)

    if prefix == "豚" and head:
        head[0] = prefix + head[0]
        prefix = ""
    elif prefix == "若鶏" and head:
        head[0] = prefix + head[0]
        prefix = ""
    elif prefix == "いのしし" and head and head[0] == "肉":
        head[0] = prefix + "肉"
        prefix = ""

    if not head and not prefix and shelf:
        label = SHELF_LABEL.get(shelf[0], shelf[0])
        if label not in DROP_TOKENS:
            head.append(label)

    qualifiers = _unique(qualifiers)
    qualifiers.sort(key=lambda item: _qualifier_rank(item))
    for note in notes:
        if note not in qualifiers:
            qualifiers.append(note)
    title_parts = [part for part in (prefix, *head) if part]
    title = " ".join(title_parts)
    if qualifiers:
        return f"{title}（{'・'.join(qualifiers)}）"
    return title


def _qualifier_rank(label: str) -> tuple[int, str]:
    order = {
        "うるち米": 10,
        "もち米": 11,
        "水稲めし": 12,
        "大型種": 20,
        "無発酵": 30,
        "養殖": 35,
        "天然": 36,
        "国産": 37,
        "皮なし": 40,
        "皮つき": 41,
        "脂身つき": 42,
        "皮下脂肪なし": 43,
        "赤肉": 44,
        "赤身": 45,
        "全粒": 60,
        "全脂無糖": 61,
        "全卵型": 62,
        "全卵": 63,
        "こしあん": 64,
        "浸出液": 70,
        "素干し": 71,
        "生": 80,
        "ゆで": 81,
        "焼き": 82,
        "乾": 83,
    }
    return (order.get(label, 50), label)


def _unique(items: list[str]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for item in items:
        if item in seen:
            continue
        seen.add(item)
        out.append(item)
    return out


def _katakana_to_hiragana(text: str) -> str:
    out: list[str] = []
    for char in text:
        code = ord(char)
        if 0x30A1 <= code <= 0x30F6:
            out.append(chr(code - 0x60))
        else:
            out.append(char)
    return "".join(out)


def token_reading(token: str) -> str:
    if token in TOKEN_READING:
        return TOKEN_READING[token]
    folded = _katakana_to_hiragana(token)
    if folded != token and not _KANJI.search(folded):
        return folded
    if not _KANJI.search(token):
        return token
    raise KeyError(f"no hiragana reading for token {token!r}")


def draft_reading(display_name: str) -> str:
    bare = display_name.replace("（", " ").replace("）", " ").replace("・", " ")
    parts = [token_reading(token) for token in bare.split() if token]
    return " ".join(parts)


def search_reading(reading: str) -> str:
    return normalize_food_search_text(reading)


def review_aliases(
    foods: list[DraftFood],
    drafts: list[AliasDraft],
) -> tuple[list[AliasDraft], list[RejectedAlias]]:
    """Reject a bad alias before it can knock out a good one.

    Part mismatches, dish mismatches, and exact names of another food are
    removed first. Only the rows that survive are grouped. A word that still
    points at several foods must be a candidate on each of them. A word that
    points at one food, but is contained in another food's label, is not
    treated as unique.
    """
    by_code = {item.food.food_code: item for item in foods}
    rejected: list[RejectedAlias] = []
    pending: list[tuple[str, AliasDraft]] = []
    for draft in drafts:
        key = normalize_food_search_text(draft.alias)
        reason = _item_reason(draft, key, by_code)
        if reason:
            rejected.append(RejectedAlias(draft, reason))
        else:
            pending.append((key, draft))

    grouped: dict[str, list[AliasDraft]] = {}
    for key, draft in pending:
        grouped.setdefault(key, []).append(draft)

    accepted: list[AliasDraft] = []
    for key, group in grouped.items():
        codes = {item.food_code for item in group}
        survivors = group
        if len(codes) > 1:
            for item in group:
                if not item.is_candidate:
                    rejected.append(
                        RejectedAlias(item, "複数の食品に付く別名は、すべて候補にする")
                    )
            survivors = [item for item in group if item.is_candidate]
        for item in survivors:
            if not item.is_candidate and _other_foods_contain(key, item.food_code, by_code):
                rejected.append(
                    RejectedAlias(
                        item,
                        "同じ語を含む他の食品があるので、1件への一意の別名にはしない",
                    )
                )
            else:
                accepted.append(item)
    return accepted, rejected


def _item_reason(draft: AliasDraft, key: str, by_code: dict[str, DraftFood]) -> str:
    if not key or len(key) < 2:
        return "正規化後が2文字未満"
    if draft.alias in GENERIC_ALIASES or key in {
        normalize_food_search_text(word) for word in GENERIC_ALIASES
    }:
        return "食品を特定できない汎用語"
    target = by_code.get(draft.food_code)
    if target is None:
        return "見本に無い食品番号"
    if not _parts_agree(draft, target):
        return "別名の部位・種類が、その食品の名称に無い"
    dish = _dish_reason(draft, target)
    if dish:
        return dish
    target_head = normalize_food_search_text(target.display_name.split("（", 1)[0])
    owner = _exact_other_name(key, draft.food_code, by_code)
    # The same short name on two cuts (和牛サーロインの脂身つきと皮下脂肪なし)
    # is not a mistaken attachment. A different food's exact name is.
    if owner and target_head != key:
        return f"食品番号 {owner} の表示名または読みと完全一致する"
    return ""


def _dish_reason(draft: AliasDraft, target: DraftFood) -> str:
    """料理名は、注記付きの候補として、その料理の食品にだけ付ける。"""
    if "丼" not in draft.alias and draft.alias not in {"牛丼の具"}:
        return ""
    blob = f"{target.food.name} {target.display_name} {draft.note}"
    related = any(word in blob for word in ("飯", "丼", "めし", "ご飯", "ごはん", "具"))
    if not related:
        return "料理名を、その料理と関係ない食品に付けている"
    if not draft.is_candidate or not draft.note.strip():
        return "料理名は、注記付きの候補にする"
    return ""


def _parts_agree(draft: AliasDraft, target: DraftFood) -> bool:
    # The alias reading is not evidence. "ささみ" must occur in the food itself.
    haystack = normalize_food_search_text(
        " ".join((target.food.name, target.display_name, target.reading))
    )
    for part in PART_WORDS:
        part_key = normalize_food_search_text(part)
        alias_key = normalize_food_search_text(draft.alias)
        if part_key and part_key in alias_key and part_key not in haystack:
            return False
    return True


def _other_foods_contain(key: str, food_code: str, by_code: dict[str, DraftFood]) -> bool:
    for code, food in by_code.items():
        if code == food_code:
            continue
        blob = normalize_food_search_text(f"{food.display_name} {food.reading}")
        if key in blob:
            return True
    return False


def _exact_other_name(key: str, food_code: str, by_code: dict[str, DraftFood]) -> str:
    for code, food in by_code.items():
        if code == food_code:
            continue
        names = {
            normalize_food_search_text(food.display_name.split("（", 1)[0]),
            normalize_food_search_text(food.reading),
            normalize_food_search_text(food.search_reading),
        }
        if key in names:
            return code
    return ""


def build_sample(
    foods: list[Food],
    alias_drafts: list[AliasDraft],
) -> tuple[list[DraftFood], list[RejectedAlias]]:
    drafted: list[DraftFood] = []
    for food in foods:
        display = draft_display_name(food.name)
        reading = draft_reading(display)
        drafted.append(
            DraftFood(
                food=food,
                display_name=display,
                reading=reading,
                search_reading=search_reading(reading),
            )
        )
    accepted, rejected = review_aliases(drafted, alias_drafts)
    for item in drafted:
        item.aliases = [alias for alias in accepted if alias.food_code == item.food.food_code]
    return drafted, rejected


def alias_list(aliases: list[AliasDraft]) -> str:
    parts: list[str] = []
    for alias in aliases:
        if alias.is_candidate:
            rank = "" if alias.candidate_rank is None else str(alias.candidate_rank)
            parts.append(f"{alias.alias}（候補{rank}）")
        else:
            parts.append(alias.alias)
    return " / ".join(parts)


def write_csv(path: Path, rows: list[DraftFood]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "food_group",
                "food_group_label",
                "food_code",
                "official_name",
                "display_name",
                "reading",
                "search_reading",
                "aliases",
            ],
        )
        writer.writeheader()
        for row in rows:
            writer.writerow(
                {
                    "food_group": row.food.food_group,
                    "food_group_label": GROUP_LABELS[row.food.food_group],
                    "food_code": row.food.food_code,
                    "official_name": " ".join(row.food.name.split()),
                    "display_name": row.display_name,
                    "reading": row.reading,
                    "search_reading": row.search_reading,
                    "aliases": alias_list(row.aliases),
                }
            )


def write_markdown(
    path: Path,
    rows: list[DraftFood],
    rejected: list[RejectedAlias],
) -> None:
    lines = [
        "# 食品成分表 表示名・読み・別名の見本（50件）",
        "",
        "正式名称は本番の `official_foods.name` を空白整理しただけです。",
        "display_name と読みと別名は下書きで、本番には入れていません。",
        "読みの長音を除いた検索キーが `search_reading` です。",
        "ぎゅうどん / ギュウドン / 牛丼は、別名「牛丼」（読み ぎゅうどん）の候補に揃います。",
        "",
    ]
    current = ""
    for row in rows:
        label = GROUP_LABELS[row.food.food_group]
        if label != current:
            current = label
            lines.extend([f"## {row.food.food_group} {label}", ""])
        lines.append(f"### {row.food.food_code} {row.display_name}")
        lines.append("")
        lines.append(f"- 正式名称: {' '.join(row.food.name.split())}")
        lines.append(f"- 読み: {row.reading}")
        lines.append(f"- 検索キー: {row.search_reading}")
        lines.append(f"- 別名: {alias_list(row.aliases) or '（なし）'}")
        lines.append("")
    lines.extend(["## ルールで除外した別名", ""])
    lines.append("| 食品番号 | 別名 | 理由 |")
    lines.append("| --- | --- | --- |")
    for item in rejected:
        lines.append(f"| {item.draft.food_code} | {item.draft.alias} | {item.reason} |")
    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


# Official names copied from a read-only select. Whitespace matches the table.
SAMPLE_FOODS: tuple[Food, ...] = (
    Food("01088", "01", "こめ　［水稲めし］　精白米　うるち米"),
    Food("01085", "01", "こめ　［水稲めし］　玄米"),
    Food("01089", "01", "こめ　［水稲めし］　はいが精米"),
    Food("01154", "01", "こめ　［水稲めし］　精白米　もち米"),
    Food("01026", "01", "こむぎ　［パン類］　角形食パン　食パン"),
    Food("01048", "01", "こむぎ　［中華めん類］　中華めん　ゆで"),
    Food("02017", "02", "＜いも類＞　じゃがいも　塊茎　皮なし　生"),
    Food("03001", "03", "（砂糖類）　黒砂糖"),
    Food("03033", "03", "（その他）　はちみつ　国産品　"),
    Food("04001", "04", "あずき　全粒　乾"),
    Food("04032", "04", "だいず　［豆腐・油揚げ類］　木綿豆腐"),
    Food("04046", "04", "だいず　［納豆類］　糸引き納豆"),
    Food("05001", "05", "アーモンド　乾"),
    Food("06061", "06", "（キャベツ類）　キャベツ　結球葉　生"),
    Food("06182", "06", "（トマト類）　赤色トマト　果実　生"),
    Food("07012", "07", "いちご　生"),
    Food("07107", "07", "バナナ　生"),
    Food("08001", "08", "えのきたけ　生"),
    Food("09001", "09", "あおさ　素干し"),
    Food("10003", "10", "＜魚類＞　（あじ類）　まあじ　皮つき　生"),
    Food("10134", "10", "＜魚類＞　（さけ・ます類）　しろさけ　生"),
    Food("10144", "10", "＜魚類＞　（さけ・ます類）　たいせいようさけ　養殖　皮つき　生"),
    Food("10253", "10", "＜魚類＞　（まぐろ類）　くろまぐろ　天然　赤身　生"),
    Food("11001", "11", "＜畜肉類＞　いのしし　肉　脂身つき　生"),
    Food("11015", "11", "＜畜肉類＞　うし　［和牛肉］　サーロイン　脂身つき　生"),
    Food("11016", "11", "＜畜肉類＞　うし　［和牛肉］　サーロイン　皮下脂肪なし　生"),
    Food("11029", "11", "＜畜肉類＞　うし　［和牛肉］　ヒレ　赤肉　生"),
    Food("11043", "11", "＜畜肉類＞　うし　［乳用肥育牛肉］　サーロイン　脂身つき　生"),
    Food("11059", "11", "＜畜肉類＞　うし　［乳用肥育牛肉］　ヒレ　赤肉　生"),
    Food("11071", "11", "＜畜肉類＞　うし　［輸入牛肉］　サーロイン　脂身つき　生"),
    Food("11085", "11", "＜畜肉類＞　うし　［輸入牛肉］　ヒレ　赤肉　生"),
    Food("11123", "11", "＜畜肉類＞　ぶた　［大型種肉］　ロース　脂身つき　生"),
    Food("11140", "11", "＜畜肉類＞　ぶた　［大型種肉］　ヒレ　赤肉　生"),
    Food("11220", "11", "＜鳥肉類＞　にわとり　［若どり・主品目］　むね　皮なし　生"),
    Food("11224", "11", "＜鳥肉類＞　にわとり　［若どり・主品目］　もも　皮なし　生"),
    Food("11227", "11", "＜鳥肉類＞　にわとり　［若どり・副品目］　ささみ　生"),
    Food("11288", "11", "＜鳥肉類＞　にわとり　［若どり・主品目］　むね　皮なし　焼き"),
    Food("12004", "12", "鶏卵　全卵　生"),
    Food("13003", "13", "＜牛乳及び乳製品＞　（液状乳類）　普通牛乳"),
    Food("13025", "13", "＜牛乳及び乳製品＞　（発酵乳・乳酸菌飲料）　ヨーグルト　全脂無糖"),
    Food("14001", "14", "（植物油脂類）　オリーブ油"),
    Food("14017", "14", "（バター類）　無発酵バター　有塩バター"),
    Food("15023", "15", "＜和生菓子・和半生菓子類＞　大福もち　こしあん入り"),
    Food("16037", "16", "＜茶類＞　（緑茶類）　せん茶　浸出液"),
    Food("16045", "16", "＜コーヒー・ココア類＞　コーヒー　浸出液"),
    Food("17001", "17", "＜調味料類＞　（ウスターソース類）　ウスターソース"),
    Food("17042", "17", "＜調味料類＞　（ドレッシング類）　半固体状ドレッシング　マヨネーズ　全卵型"),
    Food("18001", "18", "洋風料理　カレー類　ビーフカレー"),
    Food("18031", "18", "和風料理　煮物類　牛飯の具"),
    Food("18057", "18", "中国料理　菜類　チャーハン"),
)


def _alias(
    food_code: str,
    alias: str,
    reading: str,
    *,
    candidate: bool = False,
    rank: int | None = None,
    note: str = "",
) -> AliasDraft:
    return AliasDraft(
        food_code=food_code,
        alias=alias,
        reading=reading,
        is_candidate=candidate,
        candidate_rank=rank,
        note=note,
    )


# Common names, including drafts the rules are expected to reject.
SAMPLE_ALIAS_DRAFTS: tuple[AliasDraft, ...] = (
    _alias("01088", "ご飯", "ごはん"),
    _alias("01088", "ごはん", "ごはん"),
    _alias("01088", "白米", "はくまい", candidate=True, rank=1),
    _alias("01154", "白米", "はくまい", candidate=True, rank=2),
    _alias("01088", "白米", "はくまい"),
    _alias("01088", "ライス", "らいす"),
    _alias("01085", "玄米ご飯", "げんまいごはん"),
    _alias("01085", "玄米", "げんまい"),
    _alias("01154", "玄米", "げんまい"),
    _alias("01089", "胚芽米", "はいがまい"),
    _alias("01154", "もち米", "もちごめ"),
    _alias("01026", "食パン", "しょくぱん"),
    _alias("01026", "トースト", "とーすと"),
    _alias("01048", "ラーメン", "らーめん"),
    _alias("01048", "中華そば", "ちゅうかそば"),
    _alias("02017", "じゃがいも", "じゃがいも"),
    _alias("02017", "ポテト", "ぽてと"),
    _alias("03001", "黒糖", "こくとう"),
    _alias("03033", "蜂蜜", "はちみつ"),
    _alias("04032", "豆腐", "とうふ", candidate=True, rank=1, note="木綿を代表の候補にする"),
    _alias("04046", "納豆", "なっとう"),
    _alias("05001", "アーモンド", "あーもんど"),
    _alias("06061", "キャベツ", "きゃべつ"),
    _alias("06182", "トマト", "とまと"),
    _alias("07012", "イチゴ", "いちご"),
    _alias("07107", "バナナ", "ばなな"),
    _alias("08001", "えのき", "えのき"),
    _alias("09001", "アオサ", "あおさ"),
    _alias("10003", "アジ", "あじ"),
    _alias("10003", "真あじ", "まあじ"),
    _alias("10134", "鮭", "さけ"),
    _alias("10134", "サーモン", "さーもん", candidate=True, rank=2, note="しろさけ。たいせいようさけと候補を分ける"),
    _alias("10144", "サーモン", "さーもん", candidate=True, rank=1, note="たいせいようさけ。市販のサーモンに近い候補"),
    _alias("10144", "アトランティックサーモン", "あとらんてぃっくさーもん"),
    _alias("10253", "本マグロ", "ほんまぐろ"),
    _alias("10253", "マグロ赤身", "まぐろあかみ"),
    _alias("11001", "猪肉", "いのししにく"),
    _alias("11001", "牛肉", "ぎゅうにく"),
    _alias("11015", "和牛サーロイン", "わぎゅうさーろいん"),
    _alias("11015", "サーロイン", "さーろいん"),
    _alias("11015", "サーロイン", "さーろいん", candidate=True, rank=1),
    _alias("11043", "サーロイン", "さーろいん", candidate=True, rank=2),
    _alias("11071", "サーロイン", "さーろいん", candidate=True, rank=3),
    _alias("11043", "乳用牛サーロイン", "にゅうようぎゅうさーろいん"),
    _alias("11071", "輸入サーロイン", "ゆにゅうさーろいん"),
    _alias("11016", "和牛サーロイン脂なし", "わぎゅうさーろいんあぶらなし"),
    _alias("11029", "和牛ヒレ", "わぎゅうひれ"),
    _alias("11029", "和牛フィレ", "わぎゅうひれ"),
    _alias("11029", "ヒレ", "ひれ"),
    _alias("11029", "ヒレ", "ひれ", candidate=True, rank=1),
    _alias("11059", "ヒレ", "ひれ", candidate=True, rank=2),
    _alias("11085", "ヒレ", "ひれ", candidate=True, rank=3),
    _alias("11140", "ヒレ", "ひれ", candidate=True, rank=4),
    _alias("11059", "乳用牛ヒレ", "にゅうようぎゅうひれ"),
    _alias("11085", "輸入ヒレ", "ゆにゅうひれ"),
    _alias("11123", "豚ロース", "ぶたろーす"),
    _alias("11140", "豚ヒレ", "ぶたひれ"),
    _alias("11220", "鶏むね", "とりむね", candidate=True, rank=1),
    _alias("11288", "鶏むね", "とりむね", candidate=True, rank=2),
    _alias("11220", "鶏むね", "とりむね"),
    _alias("11220", "ささみ", "ささみ"),
    _alias("11227", "ささみ", "ささみ"),
    _alias("11227", "鶏ささみ", "とりささみ"),
    _alias("11224", "鶏もも", "とりもも"),
    _alias("11288", "鶏むね焼き", "とりむねやき"),
    _alias("12004", "卵", "たまご"),
    _alias("12004", "生卵", "なまたまご"),
    _alias("13003", "牛乳", "ぎゅうにゅう"),
    _alias("13025", "ヨーグルト", "よーぐると"),
    _alias("14001", "オリーブオイル", "おりーぶおいる"),
    _alias("14017", "バター", "ばたー"),
    _alias("15023", "大福", "だいふく"),
    _alias("16037", "緑茶", "りょくちゃ"),
    _alias("16037", "煎茶", "せんちゃ"),
    _alias("16045", "コーヒー", "こーひー"),
    _alias("17001", "ウスターソース", "うすたーそーす"),
    _alias("17042", "マヨネーズ", "まよねーず"),
    _alias("18001", "ビーフカレー", "びーふかれー"),
    _alias("18031", "牛丼", "ぎゅうどん", candidate=True, rank=1, note="牛丼そのものは未収載。具の候補"),
    _alias("01088", "牛丼", "ぎゅうどん", candidate=True, rank=2, note="牛丼そのものは未収載。ごはんの候補"),
    _alias("11015", "牛丼", "ぎゅうどん"),
    _alias("18031", "牛丼の具", "ぎゅうどんのぐ"),
    _alias("18057", "炒飯", "ちゃーはん"),
    _alias("18057", "焼き飯", "やきめし"),
)


def main() -> None:
    rows, rejected = build_sample(list(SAMPLE_FOODS), list(SAMPLE_ALIAS_DRAFTS))
    root = Path(__file__).resolve().parents[2]
    write_csv(root / "docs/ops/official-food-label-sample-50.csv", rows)
    write_markdown(root / "docs/ops/official-food-label-sample-50.md", rows, rejected)
    print(f"foods {len(rows)} rejected {len(rejected)}")


if __name__ == "__main__":
    main()
