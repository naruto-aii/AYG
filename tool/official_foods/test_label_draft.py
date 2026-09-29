"""Rules for the 50-food display name, reading, and alias sample."""

from __future__ import annotations

import unittest

from label_draft import (
    SAMPLE_ALIAS_DRAFTS,
    SAMPLE_FOODS,
    build_sample,
)
from normalize import normalize_food_search_text


class LabelDraftTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.rows, cls.rejected = build_sample(
            list(SAMPLE_FOODS),
            list(SAMPLE_ALIAS_DRAFTS),
        )
        cls.by_code = {row.food.food_code: row for row in cls.rows}

    def test_sample_covers_every_food_group(self) -> None:
        self.assertEqual(len(self.rows), 50)
        self.assertEqual(
            {row.food.food_group for row in self.rows},
            {f"{index:02d}" for index in range(1, 19)},
        )

    def test_wagyu_sirloin_display_name(self) -> None:
        self.assertEqual(
            self.by_code["11015"].display_name,
            "和牛 サーロイン（脂身つき・生）",
        )
        self.assertEqual(
            self.by_code["11016"].display_name,
            "和牛 サーロイン（皮下脂肪なし・生）",
        )
        self.assertEqual(
            self.by_code["11043"].display_name,
            "乳用肥育牛 サーロイン（脂身つき・生）",
        )
        self.assertEqual(
            self.by_code["11071"].display_name,
            "輸入牛 サーロイン（脂身つき・生）",
        )

    def test_qualifier_order_for_fish(self) -> None:
        self.assertEqual(
            self.by_code["10144"].display_name,
            "たいせいようさけ（養殖・皮つき・生）",
        )
        self.assertEqual(
            self.by_code["10253"].display_name,
            "くろまぐろ（天然・赤身・生）",
        )

    def test_readings_are_hiragana_and_search_keys_drop_long_vowels(self) -> None:
        for row in self.rows:
            self.assertNotRegex(row.reading, r"[\u4e00-\u9fff]")
            self.assertNotRegex(row.reading, r"[\u30a1-\u30fa]")
            self.assertNotIn("ー", row.search_reading)
            self.assertNotIn(" ", row.search_reading)
        sirloin = self.by_code["11015"]
        self.assertEqual(sirloin.reading.split()[0], "わぎゅう")
        self.assertTrue(sirloin.search_reading.startswith("わぎゅうさろいん"))

    def test_gyudon_kana_normalizes_together(self) -> None:
        self.assertEqual(
            normalize_food_search_text("ぎゅうどん"),
            normalize_food_search_text("ギュウドン"),
        )
        self.assertEqual(normalize_food_search_text("牛丼"), "牛丼")

    def test_gyudon_is_only_a_noted_candidate(self) -> None:
        accepted = [
            (alias.food_code, alias.is_candidate, alias.candidate_rank)
            for row in self.rows
            for alias in row.aliases
            if alias.alias == "牛丼"
        ]
        self.assertEqual(accepted, [("01088", True, 2), ("18031", True, 1)])
        self.assertIn(
            ("11015", "料理名を、その料理と関係ない食品に付けている"),
            self._reasons("牛丼"),
        )

    def test_bare_cut_names_are_candidates(self) -> None:
        for alias, codes in (
            ("サーロイン", {"11015", "11043", "11071"}),
            ("ヒレ", {"11029", "11059", "11085", "11140"}),
            ("鶏むね", {"11220", "11288"}),
            ("白米", {"01088", "01154"}),
        ):
            hits = [
                row.food.food_code
                for row in self.rows
                for item in row.aliases
                if item.alias == alias
            ]
            self.assertEqual(set(hits), codes)
            self.assertTrue(
                all(
                    item.is_candidate
                    for row in self.rows
                    for item in row.aliases
                    if item.alias == alias
                )
            )

    def test_sasami_does_not_attach_to_breast(self) -> None:
        breast = [item.alias for item in self.by_code["11220"].aliases]
        tender = [item.alias for item in self.by_code["11227"].aliases]
        self.assertNotIn("ささみ", breast)
        self.assertIn("ささみ", tender)
        self.assertIn(
            ("11220", "別名の部位・種類が、その食品の名称に無い"),
            self._reasons("ささみ"),
        )

    def test_genmai_does_not_attach_to_mochi_rice(self) -> None:
        self.assertIn("玄米", [item.alias for item in self.by_code["01085"].aliases])
        self.assertNotIn("玄米", [item.alias for item in self.by_code["01154"].aliases])

    def test_wagyu_sirloin_is_not_a_unique_alias(self) -> None:
        aliases = [item.alias for item in self.by_code["11015"].aliases]
        self.assertNotIn("和牛サーロイン", aliases)
        self.assertTrue(any("11016" in reason for _, reason in self._reasons("和牛サーロイン")))

    def test_generic_and_short_aliases_are_rejected(self) -> None:
        self.assertIn(("11001", "食品を特定できない汎用語"), self._reasons("牛肉"))
        self.assertIn(("10134", "正規化後が2文字未満"), self._reasons("鮭"))
        self.assertIn(("12004", "正規化後が2文字未満"), self._reasons("卵"))

    def _reasons(self, alias: str) -> list[tuple[str, str]]:
        return [
            (item.draft.food_code, item.reason)
            for item in self.rejected
            if item.draft.alias == alias
        ]


if __name__ == "__main__":
    unittest.main()
