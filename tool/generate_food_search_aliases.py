#!/usr/bin/env python3
"""Build hiragana/kanji/colloquial aliases for every official food.

Rules apply to the whole composition table. They do not list confirmation-set
queries. Review the TSV before shipping the migration.
"""

from __future__ import annotations

import csv
import re
import subprocess
from pathlib import Path

from sudachipy import dictionary, tokenizer

ROOT = Path(__file__).resolve().parents[1]
TSV = ROOT / "supabase/seed/food_search_morphology.tsv"
SQL = ROOT / "supabase/seed/food_search_morphology_insert.sql"

TOKENIZER = dictionary.Dictionary(dict="full").create()
MODE = tokenizer.Tokenizer.SplitMode.C

STOP = {
    "生", "なま", "ゆで", "茹で", "焼き", "焼", "乾", "乾燥", "水煮", "皮",
    "なし", "つき", "あり", "大型", "中型", "小型", "普通", "脂肪", "高脂肪",
    "低脂肪", "缶詰", "フレーク", "ライト", "ホワイト", "赤身", "脂身", "葉",
    "根", "類", "加工", "その他", "冷凍", "食品", "めし", "穀粒", "水稲",
    "陸稲", "うるち", "精白", "皮下", "主品目", "副品目", "国産", "輸入",
    "養殖", "天然", "若茎", "果肉", "果汁", "製品", "入り", "タイプ", "家庭用",
    "業務用", "無糖", "加糖", "全脂", "脱脂", "濃厚", "浸出液", "平均",
    "通年平均", "皮なし", "皮つき", "油いため", "素揚げ", "天ぷら", "蒸し",
    "塩漬", "漬物", "調味", "固形", "液", "粉", "粒", "水", "塩", "種",
    "全卵", "卵黄", "卵白", "砂じょう", "じょうのう", "りん茎", "塊茎",
    "塊根", "果実", "若", "親", "副生物", "大型種", "中型種",
}

# Hiragana token -> common kanji, when Sudachi keeps the token in kana.
ORTHOGRAPHY = {
    "かき": ["柿", "牡蠣"],
    "こまつな": ["小松菜"],
    "やまといも": ["山芋", "大和芋"],
    "やまのいも": ["山芋"],
    "なつみかん": ["夏みかん"],
    "めんたいこ": ["明太子"],
    "からしめんたいこ": ["明太子"],
    "かつおぶし": ["鰹節"],
    "かつお節": ["鰹節"],
    "手羽さき": ["手羽先"],
    "めんつゆ": ["麺つゆ"],
    "しょうゆ": ["醤油", "しょう油"],
    "からし": ["辛子"],
    "こしょう": ["胡椒"],
    "くず": ["葛"],
    "にがうり": ["苦瓜"],
    "かいわれだいこん": ["貝割れ大根"],
    "干しがき": ["干し柿"],
    "甘がき": ["甘柿"],
    "せん茶": ["煎茶"],
    "麦茶": ["麦茶"],
    "黒砂糖": ["黒糖"],
    "もも": ["桃"],
    "もち": ["餅"],
    "なし": ["梨"],
    "なす": ["茄子"],
    "ねぎ": ["葱"],
    "ふき": ["蕗"],
    "のり": ["海苔"],
    "たこ": ["蛸"],
    "えび": ["海老"],
    "いか": ["烏賊"],
    "さけ": ["鮭"],
    "しゃけ": ["鮭"],
    "さんま": ["秋刀魚"],
    "あじ": ["鯵"],
    "たい": ["鯛"],
    "ぶり": ["鰤"],
    "はまち": ["ハマチ"],
    "ひらめ": ["平目"],
    "かつお": ["鰹"],
    "うなぎ": ["鰻"],
    "あさり": ["浅蜊"],
    "しじみ": ["蜆"],
    "ほたて": ["帆立"],
    "こんぶ": ["昆布"],
    "わかめ": ["若布"],
    "ひじき": ["鹿尾菜"],
    "ごぼう": ["牛蒡"],
    "れんこん": ["蓮根"],
    "かぼちゃ": ["南瓜"],
    "だいこん": ["大根"],
    "にんじん": ["人参"],
    "たまねぎ": ["玉ねぎ"],
    "きゅうり": ["胡瓜"],
    "ほうれんそう": ["ほうれん草"],
    "はくさい": ["白菜"],
    "えだまめ": ["枝豆"],
    "しゅんぎく": ["春菊"],
    "たけのこ": ["筍"],
    "しそ": ["紫蘇"],
    "みょうが": ["茗荷"],
    "らっきょう": ["辣韮"],
    "にんにく": ["大蒜"],
    "しょうが": ["生姜"],
    "さつまいも": ["薩摩芋"],
    "じゃがいも": ["じゃがいも"],
    "さといも": ["里芋"],
    "ながいも": ["長芋"],
    "やまいも": ["山芋"],
    "こんにゃく": ["蒟蒻"],
    "しらたき": ["白滝"],
    "はるさめ": ["春雨"],
    "ぎんなん": ["銀杏"],
    "くるみ": ["胡桃"],
    "あずき": ["小豆"],
    "だいず": ["大豆"],
    "とうふ": ["豆腐"],
    "なっとう": ["納豆"],
    "ぎゅうにゅう": ["牛乳"],
    "うすくちしょうゆ": ["薄口醤油"],
    "みそ": ["味噌"],
    "たまご": ["卵"],
    "りんご": ["林檎"],
    "みかん": ["蜜柑"],
    "いちご": ["苺"],
    "ぶどう": ["葡萄"],
    "すいか": ["西瓜"],
    "びわ": ["枇杷"],
    "いちじく": ["無花果"],
    "きんかん": ["金柑"],
    "ゆず": ["柚子"],
    "すだち": ["酢橘"],
    "しいたけ": ["椎茸"],
    "まいたけ": ["舞茸"],
    "まつたけ": ["松茸"],
    "えのき": ["えのき"],
    "えのきたけ": ["えのきたけ"],
    "ぶなしめじ": ["ブナシメジ"],
    "いわし": ["鰯"],
    "さば": ["鯖"],
    "まぐろ": ["鮪"],
    "ぶた": ["豚"],
    "うし": ["牛"],
    "とり": ["鶏"],
    "ごはん": ["ご飯"],
    "はちみつ": ["蜂蜜"],
    "ぎょうざ": ["餃子"],
    "からあげ": ["唐揚げ"],
    "おこのみやき": ["お好み焼き"],
    "ちゃーはん": ["炒飯"],
    "しゅうまい": ["焼売"],
    "はるまき": ["春巻き"],
    "すぶた": ["酢豚"],
    "にくじゃが": ["肉じゃが"],
    "ぎゅうどん": ["牛丼"],
    "おやこどん": ["親子丼"],
}

VARIANTS = {
    "菠薐草": ["ほうれん草"],
    "玉葱": ["玉ねぎ"],
    "ジャガ芋": ["じゃがいも"],
    "竹の子": ["たけのこ"],
    "榎茸": ["えのきたけ"],
    "蝦": ["海老"],
    "大和芋": ["山芋"],
    "甘海老": ["甘えび"],
    "甘柿": ["柿"],
    "干し柿": ["干し柿"],
    "餡パン": ["あんぱん"],
    "黄な粉": ["きな粉"],
    "真鰯": ["いわし", "鰯"],
    "真鯛": ["たい", "鯛"],
    "蒲鉾": ["かまぼこ"],
    "落花生": ["ピーナッツ"],
    "どら焼き": ["どら焼き"],
    "ドーナツ": ["ドーナツ"],
    "小麦粉": ["小麦粉"],
    "菜種": ["菜種"],
    "糠油": ["米油", "こめ油"],
    "調製豆乳": ["調整豆乳"],
    "苦瓜": ["ゴーヤ", "ゴーヤー"],
    "貝割れ": ["かいわれ"],
    "葡萄酒": ["ワイン"],
    "煎餅": ["せんべい"],
    "若鳥": ["若鶏"],
}


def kata_to_hira(text: str) -> str:
    out = []
    for ch in text or "":
        cp = ord(ch)
        if 0x30A1 <= cp <= 0x30F6:
            out.append(chr(cp - 0x60))
        else:
            out.append(ch)
    return "".join(out)


def hira_to_kata(text: str) -> str:
    out = []
    for ch in text or "":
        cp = ord(ch)
        if 0x3041 <= cp <= 0x3096:
            out.append(chr(cp + 0x60))
        else:
            out.append(ch)
    return "".join(out)


def strip_category(text: str) -> str:
    text = re.sub(r"[<＜][^>＞]*[>＞]", " ", text or "")
    text = re.sub(r"[（(][^）)]*類[）)]", " ", text)
    return text


def has_kanji(text: str) -> bool:
    return any("\u4e00" <= ch <= "\u9fff" for ch in text)


def is_noun(text: str) -> bool:
    parts = TOKENIZER.tokenize(text, MODE)
    if len(parts) != 1:
        return False
    return parts[0].part_of_speech()[0] == "名詞"


def load_foods() -> list[dict]:
    sql = """
    copy (
      select food_code, food_group, name, display_name, coalesce(reading, '')
      from public.official_foods
      order by food_code
    ) to stdout with (format csv)
    """
    raw = subprocess.check_output(
        ["sudo", "-u", "postgres", "psql", "-d", "foodsearch", "-At", "-c", sql]
    )
    foods = []
    for row in csv.reader(raw.decode().splitlines()):
        code, group, name, display, reading = row
        foods.append(
            {
                "code": code,
                "group": group or code[:2],
                "name": name,
                "display": display or "",
                "reading": reading,
                "core": strip_category(name),
            }
        )
    return foods


class AliasSet:
    def __init__(self) -> None:
        self.rows: list[dict] = []

    def add(
        self,
        food: dict,
        alias: str,
        reading: str,
        source: str,
        rule: str,
        rank: int,
    ) -> None:
        alias = re.sub(r"\s+", "", (alias or "").strip())
        reading = kata_to_hira((reading or "").strip())
        if not alias or len(alias) > 40:
            return
        # 皮なし の「なし」などは別名にしない。口語で明示したものは残す。
        if alias in STOP and source != "colloquial_v1":
            return
        # Single kana is too broad (す, あ) except names people actually say.
        if len(alias) == 1 and not has_kanji(alias) and source != "colloquial_v1":
            return
        self.rows.append(
            {
                "food_code": food["code"],
                "display_name": food["display"],
                "alias": alias,
                "reading": reading or kata_to_hira(alias),
                "source": source,
                "rule": rule,
                "candidate_rank": rank,
                "priority": 40 if source == "colloquial_v1" else 70,
            }
        )


def form_rank(food: dict) -> int:
    blob = f"{food['display']} {food['core']} {food['name']}"
    display = food["display"]
    rank = 2
    cooked_family = (
        food["group"] == "01"
        or "だこ" in blob
        or "えだまめ" in blob
        or "うどん" in blob
        or "そば" in blob
        or "そうめん" in blob
        or "中華めん" in blob
        or "スパゲ" in blob
    )
    if cooked_family:
        if any(x in blob for x in ("ゆで", "めし", "蒸し")) and "乾" not in blob and "穀粒" not in blob and "かゆ" not in blob:
            rank = 1
        elif "穀粒" in blob or "乾" in blob:
            rank = 4
        elif "生" in blob:
            rank = 3
    elif "生）" in display or display.endswith("生）") or "（生）" in display:
        rank = 1
    elif "ゆで" in blob:
        rank = 2
    # Vegetables and fruit: the piece sold with the skin on, raw.
    if food["group"] in {"06", "07"} and "ゆで" not in blob and "油いため" not in blob:
        if "皮つき" in display and "生" in display:
            rank = 1
        elif "皮なし" in display and "生" in display:
            rank = 3
    if "若鶏" in blob or "若どり" in blob:
        rank = min(rank, 1)
    if "親・" in blob or "副品目" in blob or "副生物" in blob:
        rank = max(rank, 5)
    if "中型" in blob:
        rank += 1
    if "沖縄" in blob and ("そば" in blob or "うどん" in blob):
        rank = max(rank, 6)
    if "精粉" in blob and "板" not in blob:
        rank = max(rank, 5)
    if any(x in blob for x in ("缶詰", "果汁", "漬物", "冷凍", "粉末")):
        rank = max(rank, 4)
    if "葉（" in display or "いちょう" in blob or "ブラウン" in blob:
        rank = max(rank, 3)
    if "原藻" in display or ("カット" in display and "なめこ" in display):
        rank = max(rank, 3)
    if "減塩" in display or "薄皮" in display or "実（" in display or "脂身（" in display:
        rank = max(rank, 3)
    if "りんご" in display and "皮つき" in display:
        rank = max(rank, 3)
    if "りんご" in display and "皮なし" in display and "生" in display:
        rank = 1
    if "乾）" in display and food["group"] == "17":
        rank = max(rank, 4)
    if "うずら" in display and "肉" in display and "卵" not in display:
        rank = max(rank, 5)
    if "めかぶ" in display:
        rank = max(rank, 4)
    if "浸出液" in blob or "ドライ" in blob or "果汁" in blob or "風味" in blob:
        rank = max(rank, 4)
    if "おろし" in blob or "プレミックス" in blob:
        rank = max(rank, 6)
    if "の素" in blob or "のもと" in blob or "パウダー" in blob:
        rank = max(rank, 8)
    if "皮" in display and ("皮" == display[-1:] or "の皮" in display or "皮（" in display):
        rank = max(rank, 7)
    return rank


def add_spellings(out: AliasSet, food: dict, surface: str, reading: str, rule: str, source: str) -> None:
    rank = form_rank(food)
    reading = kata_to_hira(reading)
    out.add(food, surface, reading, source, rule, rank)
    if reading and reading != surface:
        out.add(food, reading, reading, source, rule, rank)
        kata = hira_to_kata(reading)
        if kata != reading:
            out.add(food, kata, reading, source, rule, rank)


def chunks_of(text: str) -> list[str]:
    parts = re.split(r"[\s　（）()＜＞<>・、,]+", text or "")
    return [part.strip() for part in parts if part and part.strip()]


def reading_of(surface: str) -> str:
    parts = TOKENIZER.tokenize(surface, MODE)
    if len(parts) == 1:
        return kata_to_hira(parts[0].reading_form() or "")
    readings = []
    for morph in parts:
        if morph.part_of_speech()[0] in {"補助記号", "空白", "助詞", "助動詞"}:
            continue
        reading = kata_to_hira(morph.reading_form() or "")
        if reading and reading not in {"キゴウ"}:
            readings.append(reading)
    return "".join(readings) or kata_to_hira(surface)


def stop_blocked(surface: str, food: dict) -> bool:
    if surface not in STOP:
        return False
    head = re.split(r"[ 　（(]", food["display"] or "")[0]
    if head == surface:
        return False
    if surface == "なし" and "皮なし" not in food["display"] and "皮なし" not in food["core"]:
        return False
    return True


def emit_surface(out: AliasSet, food: dict, surface: str, rule: str) -> None:
    surface = surface.strip()
    if not surface or len(surface) > 40 or surface in {"生", "（", "）", "(", ")"}:
        return
    reading = reading_of(surface)
    if stop_blocked(surface, food):
        reading_key = reading or kata_to_hira(surface)
    else:
        add_spellings(out, food, surface, reading, rule, "morphology_v1")
        reading_key = reading or kata_to_hira(surface)
    if not reading_key:
        return
    for kanji in ORTHOGRAPHY.get(reading_key, []) + ORTHOGRAPHY.get(surface, []):
        if kanji == surface or not allowed_orthography(food, reading_key, kanji):
            continue
        add_spellings(out, food, kanji, reading_key, "orthography", "morphology_v1")
    parts = TOKENIZER.tokenize(surface, MODE)
    if len(parts) != 1:
        return
    morph = parts[0]
    norm = morph.normalized_form() or ""
    if has_kanji(norm) and norm != surface and is_noun(norm):
        add_spellings(out, food, norm, reading_key, "sudachi_norm", "morphology_v1")
        for variant in VARIANTS.get(norm, []):
            add_spellings(out, food, variant, reading_key, "variant", "morphology_v1")
    dict_form = morph.dictionary_form() or ""
    if has_kanji(dict_form) and dict_form not in {surface, norm} and is_noun(dict_form):
        add_spellings(out, food, dict_form, reading_key, "sudachi_dict", "morphology_v1")
        for variant in VARIANTS.get(dict_form, []):
            add_spellings(out, food, variant, reading_key, "variant", "morphology_v1")


def morphology(food: dict, out: AliasSet) -> None:
    seen = set()
    # The display head is what the composition table calls the food, even
    # when Sudachi splits it into a verb or an adverb (なす, かき, こまつな).
    head = re.split(r"[（(]", food["display"] or "")[0].strip()
    pieces = [head] if head else []
    for text in (food["display"], food["core"], food["reading"]):
        pieces.extend(chunks_of(text or ""))
        for chunk in chunks_of(text or ""):
            for morph in TOKENIZER.tokenize(chunk, MODE):
                pos = morph.part_of_speech()[0]
                if pos in {"補助記号", "空白", "助詞", "助動詞", "接尾辞", "接頭辞"}:
                    continue
                if pos not in {"名詞", "形状詞"} and not has_kanji(morph.surface()):
                    continue
                pieces.append(morph.surface())
    for surface in pieces:
        if surface in seen:
            continue
        seen.add(surface)
        emit_surface(out, food, surface, "token")


def allowed_orthography(food: dict, reading: str, kanji: str) -> bool:
    blob = f"{food['display']} {food['core']} {food['name']}"
    group = food["group"]
    if kanji == "柿":
        return group == "07" and ("かき" in blob or "がき" in blob) and "牡蠣" not in blob
    if kanji == "牡蠣":
        return group == "10" and "かき" in food["core"] and "フライ" not in blob and "いか" not in food["core"]
    if kanji in {"醤油", "しょう油"}:
        head = food["display"].split("（")[0]
        return group == "17" and "しょうゆ" in head and "つゆ" not in head and "ソース" not in head
    if kanji == "辛子":
        return group == "17" and food["display"].startswith("からし") and "漬" not in food["display"]
    if kanji == "葛":
        return group == "02" and "くず" in food["display"] and "もち" not in food["display"]
    if kanji == "黒糖":
        return food["display"].startswith("黒砂糖")
    if kanji in {"山芋", "大和芋"}:
        return group == "02" and ("やまといも" in blob or "やまいも" in blob or "やまのいも" in blob)
    if kanji == "薄口醤油":
        return "うすくちしょうゆ" in food["display"]
    if kanji == "桃":
        return group == "07" and "もも" in blob and "すもも" not in blob and "やまもも" not in blob
    if kanji == "餅":
        head = (food["display"] or "").split(" ")[0].split("（")[0]
        return group == "01" and head in {"もち", "餅"}
    if kanji == "梨":
        return group == "07" and ("日本なし" in blob or "西洋なし" in blob)
    if kanji == "蛸":
        return "だこ" in blob or "たこ" in food["core"]
    if kanji == "海老":
        return group == "10" and "えび" in food["core"]
    if kanji == "烏賊":
        return group == "10" and "いか" in food["core"] and "たこ" not in food["core"]
    if kanji == "鮭":
        return "さけ" in blob or "ざけ" in blob or "しゃけ" in blob
    if kanji in {"秋刀魚", "鯵", "鯛", "鰤", "平目", "鰹", "鰻", "浅蜊", "蜆", "帆立", "鰯", "鯖", "鮪"}:
        return group == "10"
    if kanji in {"豚", "牛", "鶏"}:
        return group == "11"
    return True


def colloquial(food: dict, out: AliasSet) -> None:
    raw = food["name"]
    display = food["display"]
    core = food["core"]
    blob = f"{display} {core} {raw}"
    group = food["group"]
    rank = form_rank(food)

    def put(alias: str, reading: str, rule: str, rank_override: int | None = None) -> None:
        out.add(food, alias, reading, "colloquial_v1", rule, rank_override or rank)

    if group == "10" and "まぐろ" in raw and "油漬" in raw and "フレーク" in raw:
        tuna_rank = 1 if "ライト" in blob else 2 if "ホワイト" in blob else 3
        for alias, reading in (("ツナ", "つな"), ("つな", "つな"), ("ツナ缶", "つなかん")):
            put(alias, reading, "tuna_can", tuna_rank)

    if group == "10" and any(x in blob for x in ("まだこ", "みずだこ", "いいだこ")):
        octopus_rank = 1 if any(x in blob for x in ("ゆで", "蒸し")) else 4
        for alias, reading in (("たこ", "たこ"), ("タコ", "たこ"), ("蛸", "たこ"), ("ゆでだこ", "ゆでだこ")):
            use_rank = octopus_rank
            if alias == "ゆでだこ" and "ゆで" not in blob and "蒸し" not in blob:
                continue
            put(alias, reading, "octopus", use_rank)

    if group == "10" and "えび" in core and "ちり" not in core:
        shrimp_rank = rank
        if any(x in blob for x in ("くるま", "バナメイ", "大正", "あま", "しば")) and "生" in blob:
            shrimp_rank = 1
        elif "干し" in blob or "煮干" in blob:
            shrimp_rank = 6
        for alias, reading in (("えび", "えび"), ("エビ", "えび"), ("海老", "えび")):
            put(alias, reading, "shrimp", shrimp_rank)

    squid_names = ("するめいか", "けんさきいか", "ほたるいか", "あかいか", "こういか", "みみいか", "やりいか", "ひめいか", "あおりいか", "もんごういか")
    if group == "10" and any(name in blob for name in squid_names) and "たこ" not in core and "いかなご" not in blob and "おいかわ" not in blob:
        squid_rank = 1 if "するめいか" in blob and "生" in blob and "胴" not in blob and "耳" not in blob and "皮" not in blob else max(rank, 2)
        for alias, reading in (("いか", "いか"), ("イカ", "いか"), ("烏賊", "いか")):
            put(alias, reading, "squid", squid_rank)

    if group == "13" and any(
        x in display for x in ("アイスクリーム", "アイスミルク", "ラクトアイス", "ソフトクリーム")
    ):
        ice_rank = 1 if "普通脂肪" in display and "アイスクリーム" in display else 2 if "高脂肪" in display else 3
        if "ソフトクリーム" in display:
            ice_rank = 3
        for alias, reading in (("アイス", "あいす"), ("あいす", "あいす")):
            put(alias, reading, "ice_cream", ice_rank)

    if "たまご焼" in display or "卵焼" in display:
        for alias, reading in (("卵焼き", "たまごやき"), ("たまごやき", "たまごやき"), ("タマゴヤキ", "たまごやき")):
            put(alias, reading, "rolled_egg", 1 if "だし巻" in display else 2)

    if group == "11" and display.startswith("豚") and "かた" in display and "ロース" not in display and "ハム" not in display:
        if "脂身（" not in display and "ソーセージ" not in display:
            for alias, reading in (("豚こま", "ぶたこま"), ("豚コマ", "ぶたこま"), ("こま切れ", "こまぎれ")):
                put(alias, reading, "pork_komagire", 1 if "大型" in display and "脂身つき" in display else 2)

    if group == "11" and ("若鶏" in display or display.startswith("にわとり") or display.startswith("若鶏")):
        if "むね" in display and "親" not in display and "副" not in display:
            breast_rank = 1 if "皮なし" in display and "生" in display else 4 if "皮つき" in display else 5
            for alias, reading in (("鶏むね", "とりむね"), ("とりむね", "とりむね"), ("むね肉", "むねにく"), ("胸肉", "むねにく")):
                put(alias, reading, "chicken_breast", breast_rank)
        if "ささみ" in display and "生" in display and "親" not in display:
            for alias, reading in (("ささみ", "ささみ"), ("ササミ", "ささみ"), ("鶏ささみ", "とりささみ")):
                put(alias, reading, "chicken_tender", 1)
        if "もも" in display and "皮なし" in display and "生" in display and "親" not in display:
            for alias, reading in (("鶏もも", "とりもも"), ("もも肉", "ももにく")):
                put(alias, reading, "chicken_thigh", 1)
        if (
            "手羽" in display
            and "さき" not in display
            and "先" not in display
            and "もと" not in display
            and "親" not in display
        ):
            put("手羽", "てば", "chicken_wing", 1)
        if "すなぎも" in display:
            for alias, reading in (("砂肝", "すなぎも"), ("すなぎも", "すなぎも")):
                put(alias, reading, "gizzard", 1)
        if any(x in display for x in ("むね", "もも", "ささみ")) and "親" not in display and "副" not in display:
            plain_chicken = (
                "若鶏" in display
                and "生" in display
                and ("ささみ" in display or "皮なし" in display)
            )
            put("鶏肉", "とりにく", "chicken", 1 if plain_chicken else 4)
            put("とりにく", "とりにく", "chicken", 1 if plain_chicken else 4)

    if group == "11" and (display.startswith("豚") or "豚" in display) and "ソーセージ" not in display and "副生物" not in display:
        fat_only = "脂身（" in display
        processed = "ハム" in display or "ベーコン" in display
        if not fat_only and not processed:
            put("豚肉", "ぶたにく", "pork", 1 if "大型" in display and "生" in display else 3)
            put("ぶたにく", "ぶたにく", "pork", 1 if "大型" in display and "生" in display else 3)
        if "ロース" in display and "かたロース" not in display:
            loin = 1 if "大型" in display and "脂身つき" in display and "生" in display and not fat_only and not processed else 4
            put("豚ロース", "ぶたろーす", "pork_loin", loin)
            put("ロース", "ろーす", "pork_loin", loin)
        if "ばら" in display:
            belly = 1 if "大型" in display and "生" in display and not fat_only and not processed else 4
            put("豚バラ", "ぶたばら", "pork_belly", belly)
            put("豚ばら", "ぶたばら", "pork_belly", belly)
        if "もも" in display and "そともも" not in display:
            thigh = 1 if "大型" in display and "生" in display and not fat_only and not processed else 4
            put("豚もも", "ぶたもも", "pork_thigh", thigh)
        if ("ヒレ" in display or "ひれ" in display) and "とんかつ" not in display:
            fillet = 1 if "大型" in display and "生" in display and not processed else 4
            put("豚ヒレ", "ぶたひれ", "pork_fillet", fillet)
            put("ヒレ", "ひれ", "pork_fillet", fillet)
        if "ひき肉" in display:
            put("豚ひき肉", "ぶたひきにく", "pork_mince", 1)
            put("ひき肉", "ひきにく", "mince", 2)
            put("挽肉", "ひきにく", "mince", 2)

    if group == "11" and any(x in display for x in ("和牛", "乳用肥育牛", "輸入牛", "交雑")) and "脂身（" not in display and "生" in display:
        beef_rank = 1 if "和牛" in display else 2
        put("牛肉", "ぎゅうにく", "beef", beef_rank)
        put("ぎゅうにく", "ぎゅうにく", "beef", beef_rank)
        if "サーロイン" in display and "脂身つき" in display:
            put("サーロイン", "さーろいん", "sirloin", beef_rank)
        if "ひき肉" in display:
            put("牛ひき肉", "ぎゅうひきにく", "beef_mince", 1)
            put("ひき肉", "ひきにく", "mince", 3)

    if group == "12" and "鶏卵" in display and "全卵" in display and "生" in display and "加糖" not in display:
        for alias, reading in (("卵", "たまご"), ("たまご", "たまご"), ("タマゴ", "たまご"), ("生卵", "なまたまご")):
            put(alias, reading, "egg", 1)
    if group == "12" and "ゆで" in display and "全卵" in display:
        for alias, reading in (("ゆで卵", "ゆでたまご"), ("ゆでたまご", "ゆでたまご"), ("茹で卵", "ゆでたまご")):
            put(alias, reading, "boiled_egg", 1)
    if "目玉焼き" in display:
        put("目玉焼き", "めだまやき", "fried_egg", 1)
        put("めだまやき", "めだまやき", "fried_egg", 1)
    if "うずら卵" in display and "生" in display:
        put("うずら卵", "うずらたまご", "quail_egg", 1)
        put("ウズラ", "うずら", "quail_egg", 2)

    if (
        "精白米" in display
        and "水稲めし" in display
        and "もち米" not in display
        and "かゆ" not in display
        and "軟" not in display
        and "インディカ" not in display
        and "陸稲" not in display
    ):
        for alias, reading in (("ご飯", "ごはん"), ("ごはん", "ごはん"), ("白米", "はくまい"), ("白飯", "はくめし"), ("ライス", "らいす")):
            put(alias, reading, "cooked_rice", 1)
    if display.startswith("玄米") and "めし" in display and "かゆ" not in display:
        put("玄米", "げんまい", "brown_rice", 1)
        put("げんまい", "げんまい", "brown_rice", 1)
    if "全かゆ" in display and "精白米" in display:
        put("おかゆ", "おかゆ", "porridge", 1)
        put("お粥", "おかゆ", "porridge", 1)
    if display.startswith("おにぎり"):
        put("おにぎり", "おにぎり", "rice_ball", 1)
        put("おむすび", "おむすび", "rice_ball", 1)
    if display.startswith("もち（"):
        put("餅", "もち", "mochi", 1)
        put("もち", "もち", "mochi", 1)
        put("モチ", "もち", "mochi", 1)

    if group == "04" and display.startswith("木綿豆腐"):
        for alias, reading in (("豆腐", "とうふ"), ("とうふ", "とうふ"), ("トウフ", "とうふ")):
            put(alias, reading, "tofu", 1)
    if group == "04" and "絹ごし豆腐" in display:
        put("絹ごし", "きぬごし", "tofu_silken", 1)
        put("絹ごし豆腐", "きぬごしとうふ", "tofu_silken", 1)
    if "糸引き納豆" in display:
        for alias, reading in (("納豆", "なっとう"), ("なっとう", "なっとう"), ("ナットウ", "なっとう")):
            put(alias, reading, "natto", 1)
    if display in {"生揚げ", "大豆（油揚げ・生）"} or display.startswith("大豆（油揚げ"):
        put("油揚げ", "あぶらあげ", "aburaage", 1 if "油揚げ" in display else 2)
        put("あぶらあげ", "あぶらあげ", "aburaage", 1 if "油揚げ" in display else 2)
        if display == "生揚げ":
            put("厚揚げ", "あつあげ", "atsuage", 1)
            put("生揚げ", "なまあげ", "namaage", 1)
    if "がんもどき" in display:
        put("がんも", "がんも", "ganmo", 1)
        put("がんもどき", "がんもどき", "ganmo", 1)
    if "凍り豆腐" in display and "乾" in display:
        put("高野豆腐", "こうやどうふ", "koya", 1)
        put("凍り豆腐", "こおりどうふ", "koya", 1)

    if display == "普通牛乳":
        for alias, reading in (("牛乳", "ぎゅうにゅう"), ("ぎゅうにゅう", "ぎゅうにゅう"), ("ミルク", "みるく")):
            put(alias, reading, "milk", 1)
    if "ヨーグルト" in display and "全脂無糖" in display:
        put("ヨーグルト", "よーぐると", "yogurt", 1)
        put("よーぐると", "よーぐると", "yogurt", 1)
    if "プロセスチーズ" in display:
        put("チーズ", "ちーず", "cheese", 1)
    if group == "14" and "有塩バター" in display and "無発酵" in display:
        put("バター", "ばたー", "butter", 1)
    if group == "13" and display.startswith("ホイップクリーム"):
        put("生クリーム", "なまくりーむ", "cream", 1)
        put("ホイップクリーム", "ほいっぷくりーむ", "cream", 1)
    if group == "14" and display in {"調合油", "なたね油"}:
        put("サラダ油", "さらだゆ", "salad_oil", 1 if display == "調合油" else 2)

    if group == "10" and ("しろさけ" in display or "さけ" in display or "ざけ" in display):
        salmon_rank = 1 if display.startswith("しろさけ") and "生" in display and "新巻" not in display and "塩" not in display else 3
        for alias, reading in (("さけ", "さけ"), ("鮭", "さけ"), ("しゃけ", "しゃけ")):
            put(alias, reading, "salmon", salmon_rank)
    if group == "10" and any(x in display for x in ("ぎんざけ", "たいせいようさけ", "トラウト", "アトランティック")):
        put("サーモン", "さーもん", "salmon_imported", 1 if "ぎんざけ" in display and "生" in display else 2)
        if "ぎんざけ" in display:
            put("銀鮭", "ぎんざけ", "coho", 1 if "生" in display else 2)

    if group == "10" and display.startswith("まいわし") and "生" in display:
        for alias, reading in (("いわし", "いわし"), ("イワシ", "いわし"), ("鰯", "いわし")):
            put(alias, reading, "sardine", 1)
    if group == "10" and display.startswith("まさば") and "生" in display and "ごま" not in display:
        for alias, reading in (("さば", "さば"), ("サバ", "さば"), ("鯖", "さば")):
            put(alias, reading, "mackerel", 1)
    if group == "10" and display.startswith("まあじ") and "皮つき" in display and "生" in display:
        for alias, reading in (("あじ", "あじ"), ("アジ", "あじ"), ("鯵", "あじ")):
            put(alias, reading, "horse_mackerel", 1)
    if group == "10" and display.startswith("さんま") and "皮つき" in display and "生" in display:
        for alias, reading in (("さんま", "さんま"), ("サンマ", "さんま"), ("秋刀魚", "さんま")):
            put(alias, reading, "saury", 1)
    if group == "10" and "まだい" in display and "天然" in display and "生" in display:
        for alias, reading in (("たい", "たい"), ("タイ", "たい"), ("鯛", "たい")):
            put(alias, reading, "sea_bream", 1)
    if group == "10" and "くろまぐろ" in display and "赤身" in display and "生" in display and "養殖" not in display:
        for alias, reading in (("まぐろ", "まぐろ"), ("マグロ", "まぐろ"), ("鮪", "まぐろ")):
            put(alias, reading, "tuna_fish", 1)
    if "かつお 秋" in display or display.startswith("かつお 秋"):
        for alias, reading in (("かつお", "かつお"), ("カツオ", "かつお"), ("鰹", "かつお")):
            put(alias, reading, "bonito", 1)
    if "焼きのり" in display:
        put("のり", "のり", "nori", 1)
        put("海苔", "のり", "nori", 1)
        put("焼きのり", "やきのり", "nori", 1)
        put("焼海苔", "やきのり", "nori", 1)
    if "味付けのり" in display:
        put("味付けのり", "あじつけのり", "nori", 1)
        put("味海苔", "あじのり", "nori", 1)
    if "カットわかめ" in display:
        for alias, reading in (("わかめ", "わかめ"), ("ワカメ", "わかめ"), ("若布", "わかめ")):
            put(alias, reading, "wakame", 1)
    if display.startswith("まこんぶ"):
        for alias, reading in (("こんぶ", "こんぶ"), ("昆布", "こんぶ"), ("コンブ", "こんぶ")):
            put(alias, reading, "kelp", 1)
    if "ほしひじき" in display and "ステンレス" in display and "乾" in display:
        for alias, reading in (("ひじき", "ひじき"), ("ヒジキ", "ひじき")):
            put(alias, reading, "hijiki", 1)
    if display.startswith("もずく") or "おきなわもずく" in display:
        put("もずく", "もずく", "mozuku", 1 if display.startswith("もずく") else 2)
        put("モズク", "もずく", "mozuku", 1 if display.startswith("もずく") else 2)

    # Names people say, attached by the shape of the composition-table row.
    if "さつまいも" in display and "焼き" in display:
        put("焼き芋", "やきいも", "roasted_sweet_potato", 1)
        put("焼きいも", "やきいも", "roasted_sweet_potato", 1)
    if display.startswith("黒砂糖"):
        put("黒糖", "くろとう", "brown_sugar", 1)
        put("黒砂糖", "くろざとう", "brown_sugar", 1)
    if "調製豆乳" in display:
        put("調整豆乳", "ちょうせいとうにゅう", "soy_milk", 1)
        put("調製豆乳", "ちょうせいとうにゅう", "soy_milk", 1)
    if group == "05" and "ひまわり" in display:
        put("ひまわりの種", "ひまわりのたね", "sunflower_seed", 1)
    if "パインアップル" in display and "生" in display and "果汁" not in display:
        put("パイン", "ぱいん", "pineapple", 1)
        put("パイナップル", "ぱいなっぷる", "pineapple", 1)
    if "干しぶどう" in display:
        put("レーズン", "れーずん", "raisin", 1)
    if display.startswith("にがうり") and "生" in display:
        put("ゴーヤ", "ごーや", "bitter_melon", 1)
        put("ゴーヤー", "ごーやー", "bitter_melon", 1)
    if "しそ" in display and "葉" in display and "生" in display:
        put("大葉", "おおば", "shiso", 1)
    if "かいわれだいこん" in display:
        put("かいわれ大根", "かいわれだいこん", "radish_sprout", 1)
        put("かいわれ", "かいわれ", "radish_sprout", 1)
    if "やまといも" in display and "生" in display:
        put("山芋", "やまいも", "yam", 1)
    if display.startswith("くずでん粉") or display.startswith("くずでんぷん"):
        put("葛", "くず", "kudzu", 1)
        put("葛粉", "くずこ", "kudzu", 1)
    if "からしめんたいこ" in display:
        put("明太子", "めんたいこ", "pollock_roe", 1)
        put("めんたいこ", "めんたいこ", "pollock_roe", 1)
    if "かつお節" in display or "かつおぶし" in display:
        put("かつおぶし", "かつおぶし", "bonito_flake", 1)
        put("かつお節", "かつおぶし", "bonito_flake", 1)
        put("鰹節", "かつおぶし", "bonito_flake", 1)
    if "手羽さき" in display:
        put("手羽先", "てばさき", "wing_tip", 1)
    if group == "11" and "ひき肉" in display and ("和牛" in display or display.startswith("うし") or "輸入牛" in display):
        put("牛ひき肉", "ぎゅうひきにく", "beef_mince", 1 if "うし（ひき肉" in display or display.startswith("うし") else 2)
    if group == "11" and "サーロイン" in display and "生" in display and "脂身つき" in display:
        put("ステーキ", "すてーき", "steak", 1 if "和牛" in display else 2)
    if display.startswith("加工乳") and "低脂肪" in display:
        put("低脂肪牛乳", "ていしぼうぎゅうにゅう", "lowfat_milk", 1)
    if display == "なたね油":
        put("菜種油", "なたねあぶら", "rapeseed_oil", 1)
        put("なたね油", "なたねあぶら", "rapeseed_oil", 1)
    if "米ぬか油" in display:
        put("米油", "こめあぶら", "rice_oil", 1)
        put("こめ油", "こめあぶら", "rice_oil", 1)
    if display.startswith("とうもろこし油"):
        put("コーン油", "こーんゆ", "corn_oil", 1)
    if "食塩不使用" in display and "バター" in display:
        put("無塩バター", "むえんばたー", "unsalted_butter", 1)
    if "ドーナッツ" in display or "ドーナツ" in display:
        plain = "プレーン" in display and "イースト" in display
        put("ドーナツ", "どーなつ", "donut", 1 if plain else 3)
        put("ドーナッツ", "どーなっつ", "donut", 1 if plain else 3)
    if display.startswith("せん茶") and "浸出液" not in display:
        put("煎茶", "せんちゃ", "green_tea", 1)
        put("緑茶", "りょくちゃ", "green_tea", 1)
        put("せん茶", "せんちゃ", "green_tea", 1)
    if display.startswith("せん茶") and "浸出液" in display:
        put("煎茶", "せんちゃ", "green_tea", 4)
        put("緑茶", "りょくちゃ", "green_tea", 4)
        put("せん茶", "せんちゃ", "green_tea", 4)
    if "麦茶" in display:
        put("麦茶", "むぎちゃ", "barley_tea", 1)
        put("むぎ茶", "むぎちゃ", "barley_tea", 1)
    if "ぶどう酒" in display and display.endswith("赤"):
        put("赤ワイン", "あかわいん", "red_wine", 1)
        put("ワイン", "わいん", "wine", 1)
    if "ぶどう酒" in display and display.endswith("白"):
        put("白ワイン", "しろわいん", "white_wine", 1)
        put("ワイン", "わいん", "wine", 2)
    if display.startswith("こいくちしょうゆ"):
        put("しょう油", "しょうゆ", "soy_sauce", 1)
        put("醤油", "しょうゆ", "soy_sauce", 1)
        put("しょうゆ", "しょうゆ", "soy_sauce", 1)
    if display.startswith("うすくちしょうゆ") and "低塩" not in display:
        put("薄口醤油", "うすくちしょうゆ", "soy_sauce_light", 1)
    if display == "食塩":
        put("食塩", "しょくえん", "salt", 1)
        put("塩", "しお", "salt", 1)
    if "顆粒和風だし" in display:
        put("顆粒だし", "かりゅうだし", "dashi", 1)
    if "めんつゆ" in display and "ストレート" in display:
        put("麺つゆ", "めんつゆ", "noodle_sauce", 1)
        put("めんつゆ", "めんつゆ", "noodle_sauce", 1)
    if "こしょう" in display and "黒" in display and "粉" in display:
        put("ブラックペッパー", "ぶらっくぺっぱー", "black_pepper", 1)
        put("黒胡椒", "くろこしょう", "black_pepper", 1)
    if display.startswith("からし") and "粉" in display and "マスタード" not in display:
        put("辛子", "からし", "mustard", 1)
        put("からし", "からし", "mustard", 1)
    if "コーンクリームスープ" in display and "粉末" not in display:
        put("コーンスープ", "こーんすーぷ", "corn_soup", 1)
    if "ひじきのいため煮" in display:
        put("ひじきの煮物", "ひじきのにもの", "hijiki_simmer", 1)
    if display == "フライ類 えびフライ":
        put("えびフライ", "えびふらい", "shrimp_fry", 1)
        put("エビフライ", "えびふらい", "shrimp_fry", 1)
    if "うなぎ" in display and "かば焼" in display:
        put("うな丼", "うなどん", "eel_bowl", 1)
        put("蒲焼", "かばやき", "eel_bowl", 1)
    if "おおむぎ" in display and "押麦" in display and "乾" in display:
        put("押麦", "おしむぎ", "pressed_barley", 1)
    if group == "17" and (display.startswith("穀物酢") or display.startswith("米酢")):
        put("酢", "す", "vinegar", 1 if display.startswith("穀物酢") else 2)
        put("す", "す", "vinegar", 1 if display.startswith("穀物酢") else 2)
        put("お酢", "おす", "vinegar", 1 if display.startswith("穀物酢") else 2)
    if "米菓" in display and "せんべい" in display:
        put("せんべい", "せんべい", "rice_cracker", 1)
        put("煎餅", "せんべい", "rice_cracker", 1)
    if "あんパン" in display and "こしあん" in display:
        bun = 4 if "薄皮" in display else 1
        put("あんぱん", "あんぱん", "bean_bun", bun)
        put("あんパン", "あんぱん", "bean_bun", bun)
    if "どら焼" in display:
        put("どら焼き", "どらやき", "dorayaki", 1)
        put("どら焼", "どらやき", "dorayaki", 1)
    if "カバーリングチョコレート" in display:
        put("チョコレート", "ちょこれーと", "chocolate", 1)
        put("チョコ", "ちょこ", "chocolate", 2)
    if display.startswith("板こんにゃく") or "板こんにゃく" in display:
        put("こんにゃく", "こんにゃく", "konnyaku", 1)
        put("蒟蒻", "こんにゃく", "konnyaku", 1)
    if "きな粉" in display and "全粒" in display:
        put("きな粉", "きなこ", "kinako", 1)
        put("黄な粉", "きなこ", "kinako", 1)
    if display.startswith("黄大豆") and "乾" in display and "全粒" in display:
        put("大豆", "だいず", "soybean", 1)
    if display.startswith("あずき") and "全粒" in display:
        put("小豆", "あずき", "adzuki", 1 if "ゆで" in display else 3)
    if "くるみ" in display and "いり" in display and group == "05":
        put("くるみ", "くるみ", "walnut", 1)
        put("胡桃", "くるみ", "walnut", 1)
    if display.startswith("らっかせい") and "大粒" in display and "乾" in display:
        put("ピーナッツ", "ぴーなっつ", "peanut", 1)
        put("落花生", "らっかせい", "peanut", 1)
    if group == "05" and display.startswith("えごま"):
        put("えごま", "えごま", "perilla_seed", 1)
    if "オレンジ" in display and "ネーブル" in display and "生" in display:
        put("オレンジ", "おれんじ", "orange", 1)
    if display.startswith("日本なし") and "生" in display:
        put("なし", "なし", "pear", 1)
        put("ナシ", "なし", "pear", 1)
        put("梨", "なし", "pear", 1)
    if "あまのり" in display and "焼きのり" in display:
        put("のり", "のり", "nori", 1)
        put("海苔", "のり", "nori", 1)
    if display.startswith("まいわし") and "生" in display and "フライ" not in display:
        put("いわし", "いわし", "sardine", 1)
    if "まだい" in display and "天然" in display and "生" in display:
        put("たい", "たい", "sea_bream", 1)
    if "あまえび" in display and "生" in display:
        put("甘えび", "あまえび", "sweet_shrimp", 1)
        put("甘海老", "あまえび", "sweet_shrimp", 1)
    if display.startswith("蒸しかまぼこ"):
        put("かまぼこ", "かまぼこ", "kamaboko", 1)
        put("蒲鉾", "かまぼこ", "kamaboko", 1)
    if display.startswith("焼き竹輪"):
        put("ちくわ", "ちくわ", "chikuwa", 1)
        put("竹輪", "ちくわ", "chikuwa", 1)
    if "うなぎ" in display and "かば焼" in display:
        put("うなぎ", "うなぎ", "eel", 1)
    if display.startswith("するめいか") and "生" in display and "胴" not in display:
        put("するめいか", "するめいか", "squid", 1)
    if "即席みそ" in display:
        put("味噌", "みそ", "miso", 1 if "粉末" in display else 2)
        put("みそ", "みそ", "miso", 1 if "粉末" in display else 2)
    if display.startswith("フライ類 メンチカツ"):
        put("メンチカツ", "めんちかつ", "menchi", 1)
    if display.startswith("麻婆豆腐"):
        put("マーボー豆腐", "まーぼーどうふ", "mapo", 1)
    if "ひじき" in display and group == "09" and "ステンレス" in display and "乾" in display:
        put("ひじき", "ひじき", "hijiki", 1)

    if display.startswith("しょうが（") and "生" in display:
        put("しょうが", "しょうが", "ginger", 1)
        put("生姜", "しょうが", "ginger", 1)
        put("ショウガ", "しょうが", "ginger", 1)
    if "しょうが" in display and ("おろし" in display or "葉しょうが" in display or "パウダー" in display):
        put("しょうが", "しょうが", "ginger", 6)
        put("生姜", "しょうが", "ginger", 6)
    if display.startswith("青ピーマン") and "生" in display:
        put("ピーマン", "ぴーまん", "pepper", 1)
        put("ぴーまん", "ぴーまん", "pepper", 1)
    if "ピーマン" in display and not display.startswith("青ピーマン"):
        put("ピーマン", "ぴーまん", "pepper", 4)
    if display.startswith("ながいも（"):
        put("ながいも", "ながいも", "yam", 1)
        put("長芋", "ながいも", "yam", 1)
    if "いちょういも" in display or "やまといも" in display:
        put("ながいも", "ながいも", "yam", 3)
        put("長芋", "ながいも", "yam", 3)
    if "フライドポテト" in display:
        potato = 1 if "市販" in display else 3
        put("フライドポテト", "ふらいどぽてと", "fries", potato)
    if display == "生揚げ":
        put("生揚げ", "なまあげ", "namaage", 1)
    if "絹生揚げ" in display:
        put("生揚げ", "なまあげ", "namaage", 4)
    if display.startswith("いんげんまめ"):
        put("いんげん", "いんげん", "bean", 1 if "ゆで" in display else 3)
    if "甘納豆" in display and "いんげん" in display:
        put("いんげん", "いんげん", "bean", 6)
    if display.startswith("アーモンド"):
        put("アーモンド", "あーもんど", "almond", 1 if "乾" in display and "フライ" not in display else 4)
        put("あーもんど", "あーもんど", "almond", 1 if "乾" in display and "フライ" not in display else 4)
    if group == "05" and display.startswith("かぼちゃ"):
        put("かぼちゃの種", "かぼちゃのたね", "pumpkin_seed", 1)
    if "うんしゅうみかん" in display:
        mikan = 1 if "普通" in display and "生" in display else 3
        put("温州みかん", "うんしゅうみかん", "mikan", mikan)
        put("うんしゅうみかん", "うんしゅうみかん", "mikan", mikan)
    if "レモン" in display and "全果" in display:
        put("レモン", "れもん", "lemon", 1)
        put("れもん", "れもん", "lemon", 1)
    if "レモン" in display and ("果汁" in display or "缶" in display or "風味" in display):
        put("レモン", "れもん", "lemon", 5)
        put("れもん", "れもん", "lemon", 5)
    if display.startswith("マンゴー（"):
        put("マンゴー", "まんごー", "mango", 1)
        put("まんごー", "まんごー", "mango", 1)
    if "ドライマンゴー" in display:
        put("マンゴー", "まんごー", "mango", 4)
    if display.startswith("マッシュルーム（"):
        put("マッシュルーム", "まっしゅるーむ", "mushroom", 1)
        put("まっしゅるーむ", "まっしゅるーむ", "mushroom", 1)
    if "ブラウン種" in display and "マッシュルーム" in display:
        put("マッシュルーム", "まっしゅるーむ", "mushroom", 3)
    if display.startswith("生しいたけ") or "生しいたけ" in display:
        put("しいたけ", "しいたけ", "shiitake", 1)
    if "乾しいたけ" in display:
        put("しいたけ", "しいたけ", "shiitake", 4)
    if "カットわかめ" in display:
        put("わかめ", "わかめ", "wakame", 1)
    if "めかぶ" in display:
        put("わかめ", "わかめ", "wakame", 4)
    if display.startswith("まこんぶ"):
        put("こんぶ", "こんぶ", "kelp", 1)
    if "えながおにこんぶ" in display:
        put("こんぶ", "こんぶ", "kelp", 4)
    if group == "09" and "ひじき" in display:
        put("ひじき", "ひじき", "hijiki", 1)
    if "おかひじき" in display:
        put("ひじき", "ひじき", "hijiki", 5)
    if "鶏卵" in display and "卵黄" in display and "生" in display and "マヨ" not in display:
        put("卵黄", "らんおう", "yolk", 1)
    if "卵黄型" in display or ("マヨネーズ" in display and "卵黄" in display):
        put("卵黄", "らんおう", "yolk", 6)
    if "鶏卵" in display and "卵白" in display:
        put("卵白", "らんぱく", "white", 1)
    if "無糖練乳" in display:
        put("練乳", "れんにゅう", "condensed_milk", 1)
        put("れんにゅう", "れんにゅう", "condensed_milk", 1)
    if display == "ごま油":
        put("ごま油", "ごまあぶら", "sesame_oil", 1)
        put("ごまあぶら", "ごまあぶら", "sesame_oil", 1)
    if "えごま油" in display:
        put("ごま油", "ごまあぶら", "sesame_oil", 5)
    if "有塩バター" in display:
        put("有塩バター", "ゆうえんばたー", "salted_butter", 1 if "無発酵" in display or display.startswith("有塩") else 3)
    if "今川焼" in display:
        put("今川焼", "いまがわやき", "imagawayaki", 1 if "こしあん" in display else 2)
    if "みりん" in display and "干し" in display:
        put("みりん", "みりん", "mirin", 6)
    if "本みりん" in display:
        put("みりん", "みりん", "mirin", 1)
    if "米みそ" in display or "金山寺" in display or "ひしお" in display:
        put("みそ", "みそ", "miso", 5)
        put("味噌", "みそ", "miso", 5)
    if "カレーパン" in display or "カレールウ" in display:
        put("カレー", "かれー", "curry", 5)
        put("かれー", "かれー", "curry", 5)
    if display.startswith("ウスターソース"):
        put("ソース", "そーす", "sauce", 1)
    if display.startswith("中濃ソース"):
        put("ソース", "そーす", "sauce", 2)
    if display.startswith("濃厚ソース"):
        put("ソース", "そーす", "sauce", 3)
    if "鶏がらだし" in display:
        put("鶏がらスープ", "とりがらすーぷ", "chicken_stock", 1)
        put("鶏ガラスープ", "とりがらすーぷ", "chicken_stock", 1)
    if "うずら" in display and "肉" in display and "卵" not in display:
        put("ウズラ", "うずら", "quail", 5)
        put("うずら", "うずら", "quail", 5)
    if "うこっけい" in display:
        put("たまご", "たまご", "egg", 4)
        put("卵", "たまご", "egg", 4)
    if group == "12" and display.startswith("鶏卵（"):
        put("たまご", "たまご", "egg", 1)
        put("卵", "たまご", "egg", 1)

    if "トマトケチャップ" in display:
        put("ケチャップ", "けちゃっぷ", "ketchup", 1)
        put("けちゃっぷ", "けちゃっぷ", "ketchup", 1)
    if display == "カステラ":
        put("カステラ", "かすてら", "castella", 1)
        put("かすてら", "かすてら", "castella", 1)
    if "カステラまんじゅう" in display:
        put("カステラ", "かすてら", "castella", 4)
        put("かすてら", "かすてら", "castella", 4)
    if display.startswith("こいくちしょうゆ") and "減塩" not in display:
        put("こいくちしょうゆ", "こいくちしょうゆ", "soy_sauce", 1)
    if "減塩" in display and "しょうゆ" in display:
        put("こいくちしょうゆ", "こいくちしょうゆ", "soy_sauce", 4)
    if "株採り" in display and "なめこ" in display:
        put("なめこ", "なめこ", "nameko", 1)
    if "カットなめこ" in display:
        put("なめこ", "なめこ", "nameko", 3)
    if "しそ" in display and "実" in display:
        put("しそ", "しそ", "shiso", 4)
    if "しそ" in display and "葉" in display and "生" in display:
        put("しそ", "しそ", "shiso", 1)
    if group == "06" and "葉" in display and "生" in display and ("パセリ" in display or "バジル" in display):
        herb = "パセリ" if "パセリ" in display else "バジル"
        put(herb, "ぱせり" if herb == "パセリ" else "ばじる", "herb", 1)
    if group == "17" and ("パセリ" in display or "バジル" in display):
        herb = "パセリ" if "パセリ" in display else "バジル"
        put(herb, "ぱせり" if herb == "パセリ" else "ばじる", "herb", 4)
    if "りんご" in display and "皮なし" in display and "生" in display:
        put("りんご", "りんご", "apple", 1)
        put("林檎", "りんご", "apple", 1)
    if "りんご" in display and ("皮つき" in display or "ジュース" in display or "果実飲料" in display):
        put("りんご", "りんご", "apple", 3)
        put("林檎", "りんご", "apple", 3)
    if "果皮" in display and ("すだち" in display or "ゆず" in display):
        put("すだち" if "すだち" in display else "ゆず", "すだち" if "すだち" in display else "ゆず", "citrus_peel", 1)
        if "ゆず" in display:
            put("柚子", "ゆず", "citrus_peel", 1)
    if display.startswith("せん茶") and "浸出液" not in display:
        put("緑茶", "りょくちゃ", "green_tea", 1)
    if "浸出液" in display and display.startswith("せん茶"):
        put("緑茶", "りょくちゃ", "green_tea", 4)

    # The plain form of a name outranks a label that points at a rarer cut.
    head = re.split(r"[ 　（(]", display)[0]
    if head and head not in STOP and len(head) >= 2:
        put(head, reading_of(head), "head_form", rank)
        for kanji in ORTHOGRAPHY.get(kata_to_hira(head), []):
            if allowed_orthography(food, kata_to_hira(head), kanji):
                put(kanji, kata_to_hira(head), "head_form", rank)

    # Cooked dishes whose official name is kana.
    dish = {
        "ビーフカレー": [("カレー", "かれー"), ("かれー", "かれー"), ("ビーフカレー", "びーふかれー")],
        "ぎょうざ": [("餃子", "ぎょうざ"), ("ぎょうざ", "ぎょうざ"), ("ギョーザ", "ぎょうざ")],
        "とりから揚げ": [("から揚げ", "からあげ"), ("からあげ", "からあげ"), ("唐揚げ", "からあげ")],
        "牛飯の具": [("牛丼", "ぎゅうどん"), ("ぎゅうどん", "ぎゅうどん")],
        "親子丼の具": [("親子丼", "おやこどん"), ("おやこどん", "おやこどん")],
        "肉じゃが": [("肉じゃが", "にくじゃが"), ("にくじゃが", "にくじゃが")],
        "酢豚": [("酢豚", "すぶた"), ("すぶた", "すぶた")],
        "麻婆豆腐": [("麻婆豆腐", "まーぼーどうふ"), ("マーボー豆腐", "まーぼーどうふ")],
        "お好み焼き": [("お好み焼き", "おこのみやき"), ("おこのみやき", "おこのみやき")],
        "チャーハン": [("チャーハン", "ちゃーはん"), ("炒飯", "ちゃーはん")],
        "ハンバーグ": [("ハンバーグ", "はんばーぐ"), ("はんばーぐ", "はんばーぐ")],
        "八宝菜": [("八宝菜", "はっぽうさい")],
        "しゅうまい": [("しゅうまい", "しゅうまい"), ("焼売", "しゅうまい"), ("シュウマイ", "しゅうまい")],
        "春巻き": [("春巻き", "はるまき"), ("はるまき", "はるまき")],
    }
    for key, aliases in dish.items():
        if key in display and "皮" not in display and "プレミックス" not in display and "冷凍" not in display:
            for alias, reading in aliases:
                put(alias, reading, "dish", 1)

    if "うどん" in display and "沖縄" not in display:
        put("うどん", "うどん", "noodle", 1 if "ゆで" in display and "干し" not in display else 4)
        put("ウドン", "うどん", "noodle", 1 if "ゆで" in display and "干し" not in display else 4)
    if re.search(r"(^| )そば（", display) and "沖縄" not in display and "粉" not in display:
        put("そば", "そば", "noodle", 1 if "ゆで" in display and "干し" not in display and "半生" not in display else 4)
        put("ソバ", "そば", "noodle", 1 if "ゆで" in display and "干し" not in display else 4)
    if "そうめん" in display and "ひやむぎ" in display:
        put("そうめん", "そうめん", "noodle", 1 if "ゆで" in display else 3)
        put("素麺", "そうめん", "noodle", 1 if "ゆで" in display else 3)
    if display.startswith("中華めん") and "即席" not in display:
        put("ラーメン", "らーめん", "ramen", 1 if "ゆで" in display else 3)
        put("らーめん", "らーめん", "ramen", 1 if "ゆで" in display else 3)
        put("中華麺", "ちゅうかめん", "ramen", 1 if "ゆで" in display else 3)
    if "スパゲッティ" in display or "マカロニ" in display:
        put("パスタ", "ぱすた", "pasta", 1 if "ゆで" in display else 3)
        put("スパゲティ", "すぱげてぃ", "pasta", 1 if "ゆで" in display else 3)
        put("スパゲッティ", "すぱげってぃ", "pasta", 1 if "ゆで" in display else 3)
    if display.startswith("角形食パン"):
        put("食パン", "しょくぱん", "bread", 1)
        put("しょくぱん", "しょくぱん", "bread", 1)


def related(food: dict, row: dict) -> bool:
    if row["source"] == "colloquial_v1" or row["rule"] in {"orthography", "variant"}:
        return True
    blob = f"{food['display']} {food['core']} {food['reading']} {food['name']}"
    hira_blob = kata_to_hira(blob)
    reading = row["reading"]
    alias = row["alias"]
    if reading and reading in hira_blob:
        return True
    if alias and alias in blob:
        return True
    if kata_to_hira(alias) and kata_to_hira(alias) in hira_blob:
        return True
    return False


def main() -> None:
    foods = load_foods()
    by_code = {food["code"]: food for food in foods}
    out = AliasSet()
    for food in foods:
        morphology(food, out)
        colloquial(food, out)

    kept = []
    dropped = 0
    for row in out.rows:
        food = by_code[row["food_code"]]
        if row["source"] == "morphology_v1" and not related(food, row):
            dropped += 1
            continue
        kept.append(row)
    # A longer compound that merely starts or ends with the word
    # (ながさきはくさい, オレンジピーマン, 若鶏むね) is not the food itself.
    for row in kept:
        if row["source"] != "morphology_v1":
            continue
        food = by_code[row["food_code"]]
        alias = row["alias"]
        reading = row["reading"]
        tokens = [token.strip() for token in re.split(r"[ 　（(]", food["display"] or "") if token.strip()]
        if any(token in {alias, reading} for token in tokens):
            continue
        for token in tokens:
            token = token.strip()
            if not token or token in {alias, reading}:
                continue
            longer = len(token) > len(alias)
            touches = token.startswith(alias) or token.endswith(alias)
            if reading and reading != alias:
                touches = touches or token.startswith(reading) or token.endswith(reading)
            if longer and touches:
                row["candidate_rank"] = int(row["candidate_rank"]) + 2
                break
    best = {}
    for row in kept:
        key = (row["food_code"], row["alias"])
        prev = best.get(key)
        if prev is None:
            best[key] = row
            continue
        # Everyday names override a token that happened to rank higher.
        if row["source"] == "colloquial_v1" and prev["source"] != "colloquial_v1":
            best[key] = row
            continue
        if prev["source"] == "colloquial_v1" and row["source"] != "colloquial_v1":
            continue
        if (row["candidate_rank"], row["priority"]) < (
            prev["candidate_rank"],
            prev["priority"],
        ):
            best[key] = row
    kept = [best[key] for key in sorted(best)]
    print(f"foods {len(foods)} aliases {len(kept)} dropped_unrelated {dropped}")

    TSV.parent.mkdir(parents=True, exist_ok=True)
    with TSV.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "food_code",
                "display_name",
                "alias",
                "reading",
                "source",
                "rule",
                "candidate_rank",
                "priority",
            ],
        )
        writer.writeheader()
        writer.writerows(kept)

    # Chunked INSERT...SELECT so normalized text matches the database function.
    chunks = []
    step = 400
    for start in range(0, len(kept), step):
        values = []
        for row in kept[start : start + step]:
            alias = row["alias"].replace("'", "''")
            reading = row["reading"].replace("'", "''")
            rule = row["rule"].replace("'", "''")
            values.append(
                "('{code}','{alias}','{reading}',{rank},'{rule}','{source}',{priority})".format(
                    code=row["food_code"],
                    alias=alias,
                    reading=reading,
                    rank=row["candidate_rank"],
                    rule=rule,
                    source=row["source"],
                    priority=row["priority"],
                )
            )
        chunks.append(
            "insert into public.official_food_aliases (\n"
            "  food_code, alias, reading, normalized, is_candidate, candidate_rank,\n"
            "  note, source, is_group, priority\n"
            ")\n"
            "select distinct on (food_code, normalized)\n"
            "  food_code,\n"
            "  alias,\n"
            "  reading,\n"
            "  normalized,\n"
            "  false,\n"
            "  candidate_rank,\n"
            "  note,\n"
            "  source,\n"
            "  false,\n"
            "  priority\n"
            "from (\n"
            "  select\n"
            "    v.food_code,\n"
            "    v.alias,\n"
            "    v.reading,\n"
            "    public.normalize_food_search_text(v.alias) as normalized,\n"
            "    v.candidate_rank,\n"
            "    v.note,\n"
            "    v.source,\n"
            "    v.priority\n"
            "  from (values\n"
            + ",\n".join(values)
            + "\n  ) as v(food_code, alias, reading, candidate_rank, note, source, priority)\n"
            ") as incoming\n"
            "where normalized <> ''\n"
            "order by food_code, normalized, (source = 'colloquial_v1') desc, candidate_rank, priority\n"
            "on conflict (food_code, normalized) do update set\n"
            "  candidate_rank = excluded.candidate_rank,\n"
            "  reading = excluded.reading\n"
            "where excluded.source = 'colloquial_v1';\n"
        )
    SQL.write_text("\n".join(chunks))
    print("wrote", TSV, "and", SQL, "bytes", SQL.stat().st_size)


if __name__ == "__main__":
    main()
