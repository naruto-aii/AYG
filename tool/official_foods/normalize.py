"""Search-key normalization shared with SQL and Dart.

NFKC, compose halfwidth dakuten first, katakana to hiragana, lower case,
drop long-vowel marks and hyphens, drop whitespace.
"""

from __future__ import annotations

import unicodedata

_DAKUTEN_BASE = "ｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾊﾋﾌﾍﾎ"
_DAKUTEN_TO = "ガギグゲゴザジズゼゾダヂヅデドバビブベボ"
_HANDAKUTEN_BASE = "ﾊﾋﾌﾍﾎ"
_HANDAKUTEN_TO = "パピプペポ"
_VOICED = "\uff9e"
_SEMI = "\uff9f"
_HYPHENS = set("ーｰ-－‐‑–—−")


def compose_halfwidth_voiced(text: str) -> str:
    out: list[str] = []
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        if i + 1 < n:
            nxt = text[i + 1]
            if nxt == _VOICED and ch in _DAKUTEN_BASE:
                out.append(_DAKUTEN_TO[_DAKUTEN_BASE.index(ch)])
                i += 2
                continue
            if nxt == _SEMI and ch in _HANDAKUTEN_BASE:
                out.append(_HANDAKUTEN_TO[_HANDAKUTEN_BASE.index(ch)])
                i += 2
                continue
        out.append(ch)
        i += 1
    return "".join(out)


def normalize_food_search_text(raw: str | None) -> str:
    if not raw:
        return ""
    text = unicodedata.normalize("NFKC", compose_halfwidth_voiced(raw))
    out: list[str] = []
    for ch in text:
        code = ord(ch)
        if 0x30A1 <= code <= 0x30F6:
            ch = chr(code - 0x60)
        elif "A" <= ch <= "Z":
            ch = ch.lower()
        if ch in _HYPHENS or ch.isspace():
            continue
        out.append(ch)
    return "".join(out)


# Same strings as supabase/tests/official_foods_test.sql and
# test/food_search_normalizer_test.dart.
SHARED_CASES = (
    ("ご飯", "ご飯"),
    ("ごはん", "ごはん"),
    ("ゴハン", "ごはん"),
    ("ｺﾞﾊﾝ", "ごはん"),
    ("白米", "白米"),
    ("ライス", "らいす"),
    ("ﾗｲｽ", "らいす"),
    ("ラーメン", "らめん"),
    ("らーめん", "らめん"),
    ("トースト", "とすと"),
    ("食パン", "食ぱん"),
    ("ギョーザ", "ぎょざ"),
    ("カレーライスのルー", "かれらいすのる"),
    ("ウィンナー", "うぃんな"),
    ("ＡＢＣ", "abc"),
    ("ご　飯", "ご飯"),
    ("たまご", "たまご"),
    ("タマゴ", "たまご"),
    ("鶏むね", "鶏むね"),
    ("とうふ", "とうふ"),
    ("ぎゅうにゅう", "ぎゅうにゅう"),
)


def assert_shared_cases() -> None:
    for raw, expected in SHARED_CASES:
        got = normalize_food_search_text(raw)
        if got != expected:
            raise SystemExit(f"normalize({raw!r}) = {got!r}, expected {expected!r}")
