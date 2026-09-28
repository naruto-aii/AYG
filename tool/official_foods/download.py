#!/usr/bin/env python3
"""Resolve and download the MEXT food composition Excel files.

The index page is https://www.mext.go.jp/a_menu/syokuhinseibun/mext_00001.html.
fooddb.mext.go.jp is not used.
"""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
import urllib.request
from pathlib import Path

INDEX_URL = "https://www.mext.go.jp/a_menu/syokuhinseibun/mext_00001.html"
SITE_ORIGIN = "https://www.mext.go.jp"
USER_AGENT = "karonavi-official-foods-import/1.0"


def _absolute(href: str) -> str:
    if href.startswith("http://") or href.startswith("https://"):
        return href
    if href.startswith("/"):
        return SITE_ORIGIN + href
    return SITE_ORIGIN + "/" + href


def resolve_urls(html: str) -> tuple[str, str]:
    links = re.findall(
        r'<a\s+[^>]*href="([^"]+\.xlsx)"[^>]*>(.*?)</a>',
        html,
        flags=re.IGNORECASE | re.DOTALL,
    )
    data_url = None
    errata_url = None
    for href, inner in links:
        text = re.sub(r"<[^>]+>", "", inner)
        text = text.replace("&nbsp;", "")
        text = re.sub(r"\s+", "", text)
        url = _absolute(href)
        if data_url is None and "第2章（データ）" in text and "第2章第" not in text:
            data_url = url
        if errata_url is None and "正誤表" in text:
            errata_url = url
    if data_url is None or errata_url is None:
        raise SystemExit(
            f"could not resolve Excel URLs (data={data_url}, errata={errata_url})"
        )
    return data_url, errata_url


def fetch(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def write_with_sha256(content: bytes, path: Path) -> str:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)
    digest = hashlib.sha256(content).hexdigest()
    path.with_suffix(path.suffix + ".sha256").write_text(digest + "\n", encoding="utf-8")
    print(f"{digest}  {path}")
    return digest


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--index-url", default=INDEX_URL)
    parser.add_argument("--url", help="Override the chapter 2 data workbook URL")
    parser.add_argument("--errata-url", help="Override the errata workbook URL")
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=Path("/tmp/mext"),
        help="Directory for the downloaded workbooks (not committed)",
    )
    args = parser.parse_args(argv)

    if args.url and args.errata_url:
        data_url, errata_url = args.url, args.errata_url
    else:
        index_html = fetch(args.index_url).decode("utf-8", errors="replace")
        resolved_data, resolved_errata = resolve_urls(index_html)
        data_url = args.url or resolved_data
        errata_url = args.errata_url or resolved_errata

    print(f"data {data_url}")
    print(f"errata {errata_url}")
    data_name = data_url.rsplit("/", 1)[-1]
    errata_name = errata_url.rsplit("/", 1)[-1]
    write_with_sha256(fetch(data_url), args.out_dir / data_name)
    write_with_sha256(fetch(errata_url), args.out_dir / errata_name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
