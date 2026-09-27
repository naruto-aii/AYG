#!/usr/bin/env python3
"""Rewrite tool/dart_defines.local.json into valid JSON without asking for secrets."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

KEYS = (
    "SUPABASE_URL",
    "SUPABASE_ANON_KEY",
    "GOOGLE_WEB_CLIENT_ID",
    "GOOGLE_IOS_CLIENT_ID",
    "OFF_CONTACT_EMAIL",
    "SUPPORT_EMAIL",
)

DEFAULTS = {
    "SUPABASE_URL": "https://vdzzusqisymtejcjnikb.supabase.co",
    "SUPABASE_ANON_KEY": "",
    "GOOGLE_WEB_CLIENT_ID": "",
    "GOOGLE_IOS_CLIENT_ID": "",
    "OFF_CONTACT_EMAIL": "calonavi.ayg.support@gmail.com",
    "SUPPORT_EMAIL": "calonavi.ayg.support@gmail.com",
}

QUOTE_TRANSLATION = str.maketrans(
    {
        "\u201c": '"',
        "\u201d": '"',
        "\u2018": "'",
        "\u2019": "'",
        "\uff02": '"',
    }
)

KEY_PATTERN = re.compile(
    r'["\'](%s)["\']\s*:\s*["\']([^"\']*)["\']' % "|".join(KEYS)
)


def normalize_quotes(text: str) -> str:
    return text.translate(QUOTE_TRANSLATION)


def extract_values(text: str) -> dict[str, str]:
    data = dict(DEFAULTS)
    try:
        parsed = json.loads(normalize_quotes(text))
    except json.JSONDecodeError:
        parsed = {}
        for key, value in KEY_PATTERN.findall(normalize_quotes(text)):
            parsed[key] = value
    if not isinstance(parsed, dict):
        parsed = {}
    for key in KEYS:
        value = parsed.get(key, data[key])
        if value is None:
            value = ""
        data[key] = str(value).strip()
    if "vdzzuoqsymetlejcnkeb" in data["SUPABASE_URL"]:
        data["SUPABASE_URL"] = DEFAULTS["SUPABASE_URL"]
    return data


def render(data: dict[str, str]) -> str:
    return json.dumps({key: data[key] for key in KEYS}, indent=2, ensure_ascii=False) + "\n"


def repair(path: Path) -> tuple[bool, str]:
    if not path.exists():
        path.write_text(render(dict(DEFAULTS)), encoding="utf-8")
        return True, "created"
    original = path.read_text(encoding="utf-8")
    rewritten = render(extract_values(original))
    if rewritten == original:
        try:
            json.loads(original)
        except json.JSONDecodeError as error:
            path.write_text(rewritten, encoding="utf-8")
            return True, str(error)
        return False, "already-valid"
    path.write_text(rewritten, encoding="utf-8")
    return True, "rewritten"


def main(argv: list[str]) -> int:
    path = Path(argv[1] if len(argv) > 1 else Path(__file__).resolve().parent / "dart_defines.local.json")
    changed, reason = repair(path)
    if reason == "already-valid":
        print(f"OK: {path} is valid JSON.")
        return 0
    print(f"Wrote valid JSON to {path} ({reason}).")
    if changed:
        print("GOOGLE_IOS_CLIENT_ID is empty on purpose. Test Apple Sign-In first.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
