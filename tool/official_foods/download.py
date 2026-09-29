#!/usr/bin/env python3
"""Resolve and download the MEXT food composition Excel files.

The index page is https://www.mext.go.jp/a_menu/syokuhinseibun/mext_00001.html.
fooddb.mext.go.jp is not used. Only https://www.mext.go.jp is fetched, and
each workbook must match the pinned SHA-256 or the download is discarded.
"""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
import urllib.parse
import urllib.request
from pathlib import Path

INDEX_URL = "https://www.mext.go.jp/a_menu/syokuhinseibun/mext_00001.html"
ALLOWED_HOST = "www.mext.go.jp"
SITE_ORIGIN = f"https://{ALLOWED_HOST}"
USER_AGENT = "karonavi-official-foods-import/1.0"

# Chapter 2 workbook 20260327-mxt_kagsei-mext-000029402_02.xlsx.
DATA_WORKBOOK_SHA256 = (
    "0d5a77077dd6cd91cbc2e6e317b8b218a38728c409eed452f1c10635a0d3099c"
)
# Errata workbook 20260327-mxt_kagsei-mext-000029402_16.xlsx.
ERRATA_WORKBOOK_SHA256 = (
    "fb61037c7f66af0db1fb0729977913a629bc17097bc3ff7bf75217f9110acabb"
)


class MextUrlError(Exception):
    """The URL is not https://www.mext.go.jp."""


def assert_mext_url(url: str) -> urllib.parse.SplitResult:
    parsed = urllib.parse.urlsplit(url.strip())
    host = parsed.hostname
    if (
        parsed.scheme != "https"
        or host != ALLOWED_HOST
        or parsed.username is not None
        or parsed.password is not None
        or parsed.port not in (None, 443)
    ):
        raise MextUrlError(f"refusing URL outside https://{ALLOWED_HOST}: {url}")
    return parsed


class MextRedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        assert_mext_url(newurl)
        return super().redirect_request(req, fp, code, msg, headers, newurl)


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
        assert_mext_url(url)
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
    assert_mext_url(url)
    opener = urllib.request.build_opener(MextRedirectHandler)
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with opener.open(request, timeout=60) as response:
        assert_mext_url(response.geturl())
        return response.read()


def _discard(path: Path) -> None:
    for candidate in (
        path,
        path.with_name(path.name + ".partial"),
        path.with_suffix(path.suffix + ".sha256"),
    ):
        if candidate.exists():
            candidate.unlink()


def write_verified(content: bytes, path: Path, expected: str, label: str) -> str:
    digest = hashlib.sha256(content).hexdigest()
    if digest != expected.lower():
        _discard(path)
        raise SystemExit(
            f"sha256 mismatch for {label}: got {digest}, expected {expected}"
        )
    path.parent.mkdir(parents=True, exist_ok=True)
    partial = path.with_name(path.name + ".partial")
    partial.write_bytes(content)
    partial.replace(path)
    path.with_suffix(path.suffix + ".sha256").write_text(
        digest + "\n", encoding="utf-8"
    )
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

    assert_mext_url(args.index_url)
    if args.url and args.errata_url:
        data_url, errata_url = args.url, args.errata_url
    else:
        index_html = fetch(args.index_url).decode("utf-8", errors="replace")
        resolved_data, resolved_errata = resolve_urls(index_html)
        data_url = args.url or resolved_data
        errata_url = args.errata_url or resolved_errata
    assert_mext_url(data_url)
    assert_mext_url(errata_url)

    print(f"data {data_url}")
    print(f"errata {errata_url}")
    data_name = urllib.parse.urlsplit(data_url).path.rsplit("/", 1)[-1]
    errata_name = urllib.parse.urlsplit(errata_url).path.rsplit("/", 1)[-1]
    write_verified(
        fetch(data_url),
        args.out_dir / data_name,
        DATA_WORKBOOK_SHA256,
        "chapter 2 workbook",
    )
    write_verified(
        fetch(errata_url),
        args.out_dir / errata_name,
        ERRATA_WORKBOOK_SHA256,
        "errata workbook",
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
