"""Full-catalog labels stay inside the sample rules and the group-word list."""

from __future__ import annotations

import unittest

from label_all import group_aliases, load_foods, token_reading_any
from label_draft import draft_display_name
from normalize import normalize_food_search_text


class LabelAllTest(unittest.TestCase):
    def test_catalog_has_every_group(self) -> None:
        foods = load_foods()
        self.assertEqual(len(foods), 2538)
        self.assertEqual({food.food_group for food in foods}, {f"{i:02d}" for i in range(1, 19)})

    def test_wagyu_sirloin_label(self) -> None:
        foods = {food.food_code: food for food in load_foods()}
        self.assertEqual(
            draft_display_name(foods["11015"].name),
            "和牛 サーロイン（脂身つき・生）",
        )

    def test_problem_tokens_have_food_readings(self) -> None:
        expect = {
            "生揚げ": "なまあげ",
            "充てん豆腐": "じゅうてんとうふ",
            "乳飲料": "にゅういんりょう",
            "七分つき米": "しちぶつきまい",
            "玄米粉": "げんまいこ",
            "米粉": "こめこ",
            "甘ぐり": "あまぐり",
            "生いもこんにゃく": "なまいもこんにゃく",
            "パン粉": "ぱんこ",
            "赤米": "あかまい",
            "煮干しだし": "にぼしだし",
            "油揚げ味付け": "あぶらあげあじつけ",
            "蒸ししゃぶ": "むししゃぶ",
            "奈良漬": "ならづけ",
            "油漬": "あぶらづけ",
            "魚醤油": "ぎょしょうゆ",
            "漬物": "つけもの",
            "塩漬": "しおづけ",
            "くん製油漬缶詰": "くんせいゆづけかんづめ",
            "乾パン": "かんぱん",
            "手延そうめん": "てのべそうめん",
            "手延ひやむぎ": "てのべひやむぎ",
        }
        for token, reading in expect.items():
            self.assertEqual(token_reading_any(token), reading)

    def test_group_words_cover_the_matching_foods_only(self) -> None:
        foods = load_foods()
        aliases = group_aliases(foods)
        beef = {row.food_code for row in aliases if row.alias == "牛肉"}
        chicken = {row.food_code for row in aliases if row.alias == "チキン"}
        fish = {row.food_code for row in aliases if row.alias == "魚"}
        self.assertEqual(len(beef), 139)
        self.assertIn("11015", beef)
        self.assertNotIn("18031", beef)
        self.assertEqual(
            chicken,
            {food.food_code for food in foods if food.food_group == "11" and "にわとり" in food.name},
        )
        self.assertTrue(all(code.startswith("10") for code in fish))
        self.assertEqual(
            normalize_food_search_text("ぎゅうにく"),
            normalize_food_search_text("ギュウニク"),
        )

    def test_group_words_are_not_unique(self) -> None:
        foods = load_foods()
        aliases = group_aliases(foods)
        for word in ("牛肉", "豚肉", "鶏肉", "牛", "豚", "鶏", "肉", "魚", "ビーフ", "ポーク", "チキン"):
            codes = {row.food_code for row in aliases if row.alias == word}
            self.assertGreater(len(codes), 1, word)


if __name__ == "__main__":
    unittest.main()
