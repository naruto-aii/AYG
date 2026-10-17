"""確定済みの集計 JSON から、日本語の PDF を作る。数の意味はここでは変えない。"""

from __future__ import annotations

import hashlib
import math
import os
import tempfile
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager
from matplotlib.backends.backend_pdf import PdfPages
from matplotlib.patches import FancyBboxPatch

FONT_CANDIDATES = [
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansCJKjp-Regular.otf",
    "/usr/share/fonts/truetype/wqy/wqy-microhei.ttc",
    "/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf",
]

PAPER = "#f6f3ec"
INK = "#1c1915"
MUTED = "#6f675e"
GREEN = "#1f6b45"
GOLD = "#d3923c"
SAND = "#c9c1b4"
RED = "#9c3b32"
LINE = "#d9d2c5"
WHITE = "#fffcf7"


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


# グラフの見出しと、注記に出る英字。payload に無い文字は字形が落ちる。
_CHART_TEXT = (
    "初回起動それ以外判定なし初回起動から課金画面まで初回設定食事記録課金画面"
    "新規DLと再DLデータなし表示・ページ閲覧・転換率セッションと利用時間利用時間（分）"
    "指標当日前日比前週比注記ASA"
    "0123456789+-—〜｜・%（）.。、「」：/ ¥★_"
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
)


def _joined_text(value) -> str:
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        return "".join(_joined_text(item) for item in value.values())
    if isinstance(value, list):
        return "".join(_joined_text(item) for item in value)
    return ""


def _true_type_face(path: str, text: str) -> str:
    """CFF の日本語フォントを、使う文字だけの TrueType にする。

    pdf.fonttype = 42 は TrueType として埋め込む。CFF のまま入れると宣言と中身がずれ、
    画面では字形が落ちて、文字情報だけが残る。
    """
    from fontTools.pens.cu2quPen import Cu2QuPen
    from fontTools.pens.ttGlyphPen import TTGlyphPen
    from fontTools.subset import Options, Subsetter
    from fontTools.ttLib import TTCollection, TTFont, newTable

    source = Path(path)
    digest = hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]
    stamp = f"{source.stat().st_mtime_ns}:{source.stat().st_size}:{digest}"
    cache = Path(tempfile.gettempdir()) / f"daily-report-glyf-{source.stem}-{digest}.ttf"
    marker = cache.with_suffix(".stamp")
    if cache.is_file() and marker.is_file() and marker.read_text(encoding="utf-8") == stamp:
        return str(cache)
    if source.suffix.lower() == ".ttc":
        collection = TTCollection(path)
        font = collection.fonts[0]
        for face in collection.fonts:
            if (face["name"].getDebugName(1) or "") == "Noto Sans CJK JP":
                font = face
                break
    else:
        font = TTFont(path)
    if "glyf" in font and "CFF " not in font:
        return path
    options = Options()
    options.layout_features = ["*"]
    options.desubroutinize = True
    options.hinting = False
    options.notdef_outline = True
    subsetter = Subsetter(options=options)
    subsetter.populate(text=text)
    subsetter.subset(font)
    glyph_set = font.getGlyphSet()
    glyf = newTable("glyf")
    glyf.glyphOrder = font.getGlyphOrder()
    glyf.glyphs = {}
    for name in font.getGlyphOrder():
        pen = TTGlyphPen(glyph_set)
        glyph_set[name].draw(Cu2QuPen(pen, 1.0, reverse_direction=True))
        glyf.glyphs[name] = pen.glyph()
    font["glyf"] = glyf
    font["loca"] = newTable("loca")
    maxp = font["maxp"]
    maxp.tableVersion = 0x00010000
    for name, value in (
        ("maxZones", 1),
        ("maxTwilightPoints", 0),
        ("maxStorage", 0),
        ("maxFunctionDefs", 0),
        ("maxInstructionDefs", 0),
        ("maxStackElements", 0),
        ("maxSizeOfInstructions", 0),
        ("maxComponentElements", 0),
        ("maxComponentDepth", 0),
    ):
        setattr(maxp, name, value)
    for tag in ("CFF ", "VORG", "BASE", "GDEF", "GPOS", "GSUB"):
        if tag in font:
            del font[tag]
    font.sfntVersion = "\x00\x01\x00\x00"
    font.save(cache)
    marker.write_text(stamp, encoding="utf-8")
    return str(cache)


def render_pdf(payload: dict, destination: str | Path) -> None:
    text = _CHART_TEXT + _joined_text(payload)
    source = find_japanese_font()
    font_path = _true_type_face(source, text)
    font_manager.fontManager.addfont(font_path)
    bold_source = source.replace("Regular", "Bold")
    if bold_source != source and Path(bold_source).is_file():
        font_manager.fontManager.addfont(_true_type_face(bold_source, text))
    family = font_manager.FontProperties(fname=font_path).get_name()
    plt.rcParams["font.family"] = family
    plt.rcParams["axes.unicode_minus"] = False
    # 42 は TrueType。Type 3 だと日本語が線画になり、PDF から文字を読めない。
    plt.rcParams["pdf.fonttype"] = 42
    with PdfPages(destination) as pdf:
        _cover(pdf, payload)
        _charts(pdf, _rows(payload.get("series")))
        _table_and_notes(pdf, _rows(payload.get("table")), [str(line) for line in payload.get("notes", [])])


def _rows(value) -> list[dict]:
    if not isinstance(value, list):
        return []
    return [row for row in value if isinstance(row, dict)]


def _cover(pdf: PdfPages, payload: dict) -> None:
    figure = plt.figure(figsize=(8.27, 11.69))
    figure.patch.set_facecolor(PAPER)
    heading = str(payload.get("heading") or "")
    body = heading.removeprefix("📊").strip()
    mark = _emoji_mark()
    if mark is not None:
        axis = figure.add_axes([0.07, 0.915, 0.045, 0.045])
        axis.imshow(mark)
        axis.axis("off")
        figure.text(0.13, 0.945, body, fontsize=13, fontweight="bold", color=INK, va="center")
    else:
        figure.text(0.07, 0.945, body, fontsize=13, fontweight="bold", color=INK, va="center")
    summary = [str(line) for line in payload.get("summary", [])]
    _box(figure, 0.06, 0.74, 0.88, 0.16)
    y = 0.87
    for line in summary[:5]:
        figure.text(0.09, y, line, fontsize=10.5, color=INK, va="top")
        y -= 0.028
    cards = _rows(payload.get("cards"))[:6]
    origins = [(0.06, 0.42), (0.37, 0.42), (0.68, 0.42), (0.06, 0.12), (0.37, 0.12), (0.68, 0.12)]
    for card, (x, y_pos) in zip(cards, origins):
        _card(figure, x, y_pos, 0.26, 0.26, card)
    pdf.savefig(figure)
    plt.close(figure)


def _box(figure, x, y, width, height) -> None:
    patch = FancyBboxPatch(
        (x, y),
        width,
        height,
        boxstyle="round,pad=0.008,rounding_size=0.012",
        transform=figure.transFigure,
        facecolor=WHITE,
        edgecolor=LINE,
        linewidth=0.8,
    )
    figure.add_artist(patch)


def _card(figure, x, y, width, height, card: dict) -> None:
    _box(figure, x, y, width, height)
    figure.text(x + 0.02, y + height - 0.04, str(card.get("label", "")), fontsize=9, color=MUTED, va="top")
    value = str(card.get("value", ""))
    figure.text(
        x + 0.02,
        y + height * 0.46,
        value,
        fontsize=16 if len(value) > 8 else 22,
        fontweight="bold",
        color=INK,
        va="center",
    )
    delta = str(card.get("delta", ""))
    color = GREEN if delta.startswith("前日 +") else RED if delta.startswith("前日 -") else MUTED
    figure.text(x + 0.02, y + 0.035, delta, fontsize=10, color=color, va="bottom")


def _charts(pdf: PdfPages, series: list[dict]) -> None:
    figure, axes = plt.subplots(3, 1, figsize=(8.27, 11.69))
    figure.patch.set_facecolor(PAPER)
    figure.subplots_adjust(left=0.1, right=0.95, top=0.94, bottom=0.06, hspace=0.45)
    labels = [str(row.get("label", "")) for row in series]
    _stacked(axes[0], "初回起動", labels, series, [("asa", "ASA", GREEN), ("other", "それ以外", GOLD), ("unknown", "判定なし", SAND)])
    _lines(
        axes[1],
        "初回起動から課金画面まで",
        labels,
        series,
        [
            ("first_opens", "初回起動", GREEN),
            ("onboarding", "初回設定", "#2f6f9f"),
            ("meals", "食事記録", GOLD),
            ("paywall", "課金画面", RED),
        ],
    )
    _grouped(axes[2], "新規DLと再DL", labels, series, [("new_downloads", "新規DL", GREEN), ("redownloads", "再DL", GOLD)])
    pdf.savefig(figure)
    plt.close(figure)

    figure, axes = plt.subplots(2, 1, figsize=(8.27, 11.69))
    figure.patch.set_facecolor(PAPER)
    figure.subplots_adjust(left=0.1, right=0.8, top=0.93, bottom=0.08, hspace=0.38)
    _acquisition(axes[0], labels, series)
    _sessions(axes[1], labels, series)
    pdf.savefig(figure)
    plt.close(figure)


def _style_axis(axis, title: str) -> None:
    axis.set_title(title, fontsize=13, color=INK, loc="left", pad=10)
    axis.set_facecolor(WHITE)
    axis.spines["top"].set_visible(False)
    axis.spines["right"].set_visible(False)
    axis.spines["left"].set_color(LINE)
    axis.spines["bottom"].set_color(LINE)
    axis.tick_params(colors=MUTED, labelsize=8)
    axis.grid(axis="y", color=LINE, linewidth=0.6)
    axis.set_axisbelow(True)


def _missing(axis, title: str) -> None:
    _style_axis(axis, title)
    axis.axis("off")
    axis.text(0.5, 0.5, "データなし", ha="center", va="center", fontsize=16, color=MUTED, transform=axis.transAxes)


def _numbers(series: list[dict], key: str, allow_zero: bool) -> list[float]:
    values = []
    for row in series:
        raw = row.get(key)
        if raw is None or isinstance(raw, bool):
            values.append(math.nan)
        else:
            number = float(raw)
            values.append(number if allow_zero or number is not None else math.nan)
    return values


def _all_missing(values: list[float]) -> bool:
    return all(math.isnan(value) for value in values)


def _ticks(axis, labels: list[str]) -> None:
    axis.set_xticks(range(len(labels)))
    axis.set_xticklabels(labels, rotation=45, ha="right")


def _stacked(axis, title: str, labels: list[str], series: list[dict], parts: list[tuple[str, str, str]]) -> None:
    if not series:
        _missing(axis, title)
        return
    _style_axis(axis, title)
    bottoms = [0.0] * len(series)
    for key, name, color in parts:
        values = [float(row.get(key) or 0) for row in series]
        axis.bar(range(len(series)), values, bottom=bottoms, color=color, label=name, width=0.72)
        bottoms = [left + right for left, right in zip(bottoms, values)]
    _ticks(axis, labels)
    _headroom(axis)
    axis.legend(frameon=False, fontsize=8, loc="upper left")


def _headroom(axis) -> None:
    _, top = axis.get_ylim()
    axis.set_ylim(0, max(top * 1.35, 1))


def _lines(axis, title: str, labels: list[str], series: list[dict], parts: list[tuple[str, str, str]]) -> None:
    if not series:
        _missing(axis, title)
        return
    _style_axis(axis, title)
    for key, name, color in parts:
        values = [float(row.get(key) or 0) for row in series]
        axis.plot(range(len(series)), values, color=color, marker="o", linewidth=1.8, markersize=3.5, label=name)
    _ticks(axis, labels)
    _headroom(axis)
    axis.legend(frameon=False, fontsize=8, ncol=4, loc="upper left")


def _grouped(axis, title: str, labels: list[str], series: list[dict], parts: list[tuple[str, str, str]]) -> None:
    columns = [_numbers(series, key, True) for key, _, _ in parts]
    if not series or all(_all_missing(column) for column in columns):
        _missing(axis, title)
        return
    _style_axis(axis, title)
    width = 0.36
    for offset, column, (_, name, color) in zip((-width / 2, width / 2), columns, parts):
        present_x = []
        present_y = []
        for index, value in enumerate(column):
            if math.isnan(value):
                continue
            present_x.append(index + offset)
            present_y.append(value)
        axis.bar(present_x, present_y, width=width, color=color, label=name)
    _ticks(axis, labels)
    _headroom(axis)
    axis.legend(frameon=False, fontsize=8, loc="upper left")


def _acquisition(axis, labels: list[str], series: list[dict]) -> None:
    impressions = _numbers(series, "impressions", True)
    pages = _numbers(series, "page_views", True)
    conversion = _numbers(series, "conversion", True)
    if not series or (_all_missing(impressions) and _all_missing(pages) and _all_missing(conversion)):
        _missing(axis, "表示・ページ閲覧・転換率")
        return
    _style_axis(axis, "表示・ページ閲覧・転換率")
    width = 0.36
    for offset, column, name, color in (
        (-width / 2, impressions, "表示", GREEN),
        (width / 2, pages, "ページ閲覧", "#2f6f9f"),
    ):
        xs = [index + offset for index, value in enumerate(column) if not math.isnan(value)]
        ys = [value for value in column if not math.isnan(value)]
        axis.bar(xs, ys, width=width, color=color, label=name)
    _ticks(axis, labels)
    if not _all_missing(conversion):
        twin = axis.twinx()
        twin.plot(
            range(len(series)),
            [value * 100 if not math.isnan(value) else math.nan for value in conversion],
            color=GOLD,
            marker="o",
            linewidth=1.8,
            label="転換率",
        )
        twin.set_ylabel("転換率 %", color=MUTED, fontsize=8)
        twin.tick_params(colors=MUTED, labelsize=8)
        twin.spines["top"].set_visible(False)
        twin.spines["left"].set_visible(False)
        twin.spines["right"].set_color(LINE)
    _headroom(axis)
    axis.legend(frameon=False, fontsize=8, loc="upper left")


def _sessions(axis, labels: list[str], series: list[dict]) -> None:
    if not series:
        _missing(axis, "セッションと利用時間")
        return
    _style_axis(axis, "セッションと利用時間")
    sessions = [float(row.get("sessions") or 0) for row in series]
    minutes = [float(row.get("duration_minutes") or 0) for row in series]
    bars = axis.bar(range(len(series)), sessions, color=GREEN, width=0.62, label="セッション")
    twin = axis.twinx()
    line = twin.plot(range(len(series)), minutes, color=GOLD, marker="o", linewidth=1.8, label="利用時間（分）")
    axis.legend([bars, line[0]], ["セッション", "利用時間（分）"], frameon=False, fontsize=8, loc="upper left")
    twin.set_ylabel("分", color=MUTED, fontsize=8)
    twin.tick_params(colors=MUTED, labelsize=8)
    twin.spines["top"].set_visible(False)
    twin.spines["left"].set_visible(False)
    twin.spines["right"].set_color(LINE)
    _ticks(axis, labels)
    _headroom(axis)


def _table_and_notes(pdf: PdfPages, rows: list[dict], notes: list[str]) -> None:
    pending = list(rows)
    while pending:
        figure = plt.figure(figsize=(8.27, 11.69))
        figure.patch.set_facecolor(PAPER)
        figure.text(0.06, 0.955, "指標", fontsize=14, fontweight="bold", color=INK, va="top")
        headers = ["指標", "当日", "前日比", "前週比"]
        xs = [0.08, 0.48, 0.66, 0.82]
        y = 0.92
        for x, header in zip(xs, headers):
            figure.text(x, y, header, fontsize=9, color=MUTED, fontweight="bold", va="top")
        y -= 0.012
        figure.add_artist(plt.Line2D([0.06, 0.94], [y, y], transform=figure.transFigure, color=LINE, linewidth=0.8))
        section = ""
        used = 0
        for row in pending:
            needed = 0.028 + (0.024 if str(row.get("section", "")) != section else 0)
            if y - needed < 0.06:
                break
            y -= 0.028
            current = str(row.get("section", ""))
            if current != section:
                section = current
                figure.text(0.06, y, section, fontsize=8, color=GREEN, fontweight="bold", va="top")
                y -= 0.024
            figure.text(xs[0], y, str(row.get("metric", "")), fontsize=9, color=INK, va="top")
            figure.text(xs[1], y, str(row.get("today", "")), fontsize=9, color=INK, va="top")
            figure.text(xs[2], y, str(row.get("day", "")), fontsize=9, color=_delta_color(str(row.get("day", ""))), va="top")
            figure.text(xs[3], y, str(row.get("week", "")), fontsize=9, color=_delta_color(str(row.get("week", ""))), va="top")
            used += 1
        pdf.savefig(figure)
        plt.close(figure)
        if used == 0:
            break
        pending = pending[used:]
    _notes_page(pdf, notes)


def _notes_page(pdf: PdfPages, notes: list[str]) -> None:
    figure = plt.figure(figsize=(8.27, 11.69))
    figure.patch.set_facecolor(PAPER)
    figure.text(0.06, 0.955, "注記", fontsize=14, fontweight="bold", color=INK, va="top")
    y = 0.91
    for note in notes:
        for piece in _sentences(note):
            figure.text(0.06, y, piece, fontsize=10, color=INK, va="top")
            y -= 0.032
    pdf.savefig(figure)
    plt.close(figure)


def _delta_color(value: str) -> str:
    if value.startswith("+"):
        return GREEN
    if value.startswith("-"):
        return RED
    return INK


def _sentences(text: str) -> list[str]:
    parts = [part.strip() for part in text.split("。") if part.strip()]
    if not parts:
        return [text]
    return [part + "。" for part in parts]


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
