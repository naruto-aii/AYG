"""確定済みの集計 JSON から、日本語の PDF を作る。数の意味はここでは変えない。"""

from __future__ import annotations

import os
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager
from matplotlib.backends.backend_pdf import PdfPages

FONT_CANDIDATES = [
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansCJKjp-Regular.otf",
    "/usr/share/fonts/truetype/wqy/wqy-microhei.ttc",
    "/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf",
]


def find_japanese_font() -> str:
    override = os.environ.get("DAILY_REPORT_FONT", "").strip()
    candidates = ([override] if override else []) + FONT_CANDIDATES
    for path in candidates:
        if path and Path(path).is_file():
            return path
    raise FileNotFoundError("japanese font not found")


def bar_points(pairs: list[tuple[str, int | None]]) -> list[tuple[str, int]] | None:
    """None は描かない。全部 None のときはグラフを作らず、呼び出し側がデータなしと書く。"""
    present = [(label, value) for label, value in pairs if value is not None]
    if not present:
        return None
    return present


def render_pdf(payload: dict, destination: str | Path) -> None:
    font_path = find_japanese_font()
    font_manager.fontManager.addfont(font_path)
    bold_path = font_path.replace("Regular", "Bold")
    if bold_path != font_path and Path(bold_path).is_file():
        font_manager.fontManager.addfont(bold_path)
    family = font_manager.FontProperties(fname=font_path).get_name()
    plt.rcParams["font.family"] = family
    plt.rcParams["axes.unicode_minus"] = False
    lines = [str(line) for line in payload.get("lines", [])]
    charts = payload.get("charts") if isinstance(payload.get("charts"), dict) else {}
    with PdfPages(destination) as pdf:
        _text_page(pdf, lines)
        _chart_page(pdf, charts)


def _text_page(pdf: PdfPages, lines: list[str]) -> None:
    wrapped: list[str] = []
    for line in lines:
        if len(line) <= 42:
            wrapped.append(line)
            continue
        for start in range(0, len(line), 42):
            wrapped.append(line[start : start + 42])
    chunk: list[str] = []
    for line in wrapped:
        chunk.append(line)
        if len(chunk) == 46:
            _draw_text(pdf, chunk)
            chunk = []
    if chunk or not wrapped:
        _draw_text(pdf, chunk)


def _draw_text(pdf: PdfPages, lines: list[str]) -> None:
    figure = plt.figure(figsize=(8.27, 11.69))
    figure.patch.set_facecolor("white")
    y = 0.96
    mark = _emoji_mark()
    for line in lines:
        heading = line.startswith("📊")
        body = line.removeprefix("📊").lstrip() if heading else line
        x = 0.06
        if heading and mark is not None:
            axis = figure.add_axes([0.045, y - 0.018, 0.028, 0.028])
            axis.imshow(mark)
            axis.axis("off")
            x = 0.08
        weight = "bold" if heading or line.startswith("■") else "regular"
        figure.text(x, y, body, fontsize=9 if weight == "regular" else 11, fontweight=weight, va="top")
        y -= 0.02
    pdf.savefig(figure)
    plt.close(figure)


def _emoji_mark():
    path = "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf"
    if not Path(path).is_file():
        return None
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        return None
    image = Image.new("RGBA", (128, 128), (255, 255, 255, 0))
    draw = ImageDraw.Draw(image)
    draw.text((0, 0), "📊", font=ImageFont.truetype(path, 109), embedded_color=True)
    return image


def _chart_page(pdf: PdfPages, charts: dict) -> None:
    figure, axes = plt.subplots(2, 2, figsize=(8.27, 11.69))
    figure.patch.set_facecolor("white")
    _bars(axes[0][0], "新規DLと再DL", [
        ("新規DL", _int_or_none(_dig(charts, "downloads", "new"))),
        ("再DL", _int_or_none(_dig(charts, "downloads", "re"))),
    ])
    _bars(axes[0][1], "表示・ページ閲覧・新規DL", [
        ("表示", _int_or_none(_dig(charts, "acquisition", "impressions"))),
        ("ページ", _int_or_none(_dig(charts, "acquisition", "page_views"))),
        ("新規DL", _int_or_none(_dig(charts, "acquisition", "new_downloads"))),
    ])
    _bars(axes[1][0], "初回起動", [
        ("ASA", _int_or_none(_dig(charts, "first_opens", "asa"))),
        ("それ以外", _int_or_none(_dig(charts, "first_opens", "other"))),
        ("判定なし", _int_or_none(_dig(charts, "first_opens", "unknown"))),
    ])
    plans = charts.get("plans") if isinstance(charts.get("plans"), list) else []
    plan_pairs = []
    for plan in plans:
        if not isinstance(plan, dict):
            continue
        plan_pairs.append((str(plan.get("label", "")), _int_or_none(plan.get("paid"))))
    crashes = charts.get("crashes_by_version")
    if isinstance(crashes, list) and crashes:
        crash_pairs = []
        for row in crashes:
            if isinstance(row, dict):
                crash_pairs.append((str(row.get("key", "")), _int_or_none(row.get("crashes"))))
        _bars(axes[1][1], "クラッシュ（バージョン）", crash_pairs)
    elif plan_pairs:
        _bars(axes[1][1], "プラン別の有料有効数", plan_pairs)
    else:
        _bars(axes[1][1], "クラッシュ（バージョン）", [])
    figure.tight_layout()
    pdf.savefig(figure)
    plt.close(figure)


def _bars(axis, title: str, pairs: list[tuple[str, int | None]]) -> None:
    points = bar_points(pairs)
    axis.set_title(title, fontsize=11)
    if points is None:
        axis.axis("off")
        axis.text(0.5, 0.5, "データなし", ha="center", va="center", fontsize=14)
        return
    labels = [label for label, _ in points]
    values = [value for _, value in points]
    axis.bar(labels, values, color="#3d6b4f")
    axis.tick_params(axis="x", labelrotation=20)
    top = max(values) if values else 0
    axis.set_ylim(0, max(top * 1.25, 1))


def _dig(root: dict, key: str, child: str):
    value = root.get(key)
    if isinstance(value, dict):
        return value.get(child)
    return None


def _int_or_none(value) -> int | None:
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, float) and value.is_integer():
        return int(value)
    return None
