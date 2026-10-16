"""添付のVPの絵を、Live2Dのように動かす部品へ分ける。

静止時に見える画素は元の絵のまま。前髪の下と目の穴だけ、隣の肌や服で埋める。
閉じたまぶたと、話しているときの開いた口だけを描き足す。
"""

import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "web" / "avatar" / "source.jpg"
OUT = ROOT / "web" / "avatar"

# 目の範囲。眉より下で、白目と瞳が入る箱。
EYES = (
    {"name": "left", "box": (392, 336, 478, 398)},
    {"name": "right", "box": (540, 312, 655, 376)},
)


def save_png(path, rgba):
    Image.fromarray(rgba, "RGBA").save(path, optimize=True)


def smooth_nan(values, radius):
    out = values.copy()
    xs = np.where(~np.isnan(values))[0]
    for x in xs:
        seg = values[max(xs[0], x - radius) : min(xs[-1], x + radius) + 1]
        seg = seg[~np.isnan(seg)]
        if len(seg):
            out[x] = float(np.median(seg))
    return out


def eye_mask(rgb, dist, spec):
    x0, y0, x1, y1 = spec["box"]
    region = np.zeros(dist.shape, bool)
    region[y0:y1, x0:x1] = True
    mask = region & (dist > 30)
    mask = cv2.morphologyEx(mask.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((9, 7), np.uint8))
    mask = cv2.dilate(mask, np.ones((3, 5), np.uint8))
    count, labels, stats, _ = cv2.connectedComponentsWithStats(mask)
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    best, area = 0, 0
    for index in range(1, count):
        x, y, w, h, size = stats[index]
        if x <= cx < x + w and y <= cy < y + h and size > area:
            best, area = index, size
    if best == 0:
        return mask.astype(bool)
    return labels == best


def bounds(mask):
    ys, xs = np.where(mask)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def paint_eyelids(rgb, masks, specs):
    """閉じたまぶた。頬の色で目を覆い、元のまつ毛の色で弧を描く。"""
    from PIL import ImageDraw

    height, width = rgb.shape[:2]
    lum = rgb.astype(np.float32).mean(axis=2)
    boxes = []
    scale = 4
    canvas = Image.new("RGBA", (width * scale, height * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    for mask, spec in zip(masks, specs):
        x0, y0, x1, y1 = bounds(mask)
        skin_samples = []
        lash_samples = []
        upper = []
        for x in range(x0, x1):
            ys = np.where(mask[:, x])[0]
            if len(ys) < 2:
                continue
            upper.append((x, int(ys.min()), int(ys.max())))
            top = ys[: max(2, len(ys) // 3)]
            lash_samples.append(rgb[top[np.argmin(lum[top, x])], x])
            skin_samples.append(rgb[min(height - 1, ys.max() + 10), x])
        skin = np.median(np.array(skin_samples), axis=0)
        lash = np.clip(np.median(np.array(lash_samples), axis=0) * 0.7, 0, 255)
        skin_c = tuple(int(v) for v in skin)
        shade_c = tuple(int(v) for v in np.clip(skin * np.array([0.90, 0.84, 0.82]), 0, 255))
        lash_c = tuple(int(v) for v in lash)
        box = [x0 * scale, y0 * scale, (x1 - 1) * scale, (y1 - 1) * scale]
        draw.ellipse(box, fill=skin_c + (255,))
        crease = [x0 * scale, y0 * scale, (x1 - 1) * scale, (y0 + (y1 - y0) * 0.48) * scale]
        draw.ellipse(crease, fill=shade_c + (255,))
        lash_line = [(x * scale, (y_top + (y_bot - y_top) * 0.62) * scale) for x, y_top, y_bot in upper]
        if len(lash_line) > 3:
            draw.line(lash_line, fill=lash_c + (255,), width=scale * 2 + 1, joint="curve")
            outer = lash_line[0] if spec["name"] == "left" else lash_line[-1]
            wing = -8 * scale if spec["name"] == "left" else 8 * scale
            draw.line([outer, (outer[0] + wing, outer[1] - 4 * scale)], fill=lash_c + (255,), width=scale + 1)
        boxes.append({"x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0})
    small = canvas.resize((width, height), Image.Resampling.LANCZOS)
    return np.array(small), boxes


def paint_open_mouth(rgb):
    """笑顔の線に沿って、少しだけ口の中と歯を描く。"""
    x0, y0, x1, y1 = 468, 478, 572, 528
    crop = rgb[y0:y1, x0:x1].astype(np.float32)
    height, width = crop.shape[:2]
    lum = crop.mean(axis=2)
    line = np.array([12 + int(np.argmin(lum[12:40, x])) for x in range(width)], float)
    xs = np.arange(width)
    sel = (xs > 10) & (xs < width - 10)
    fit = np.polyval(np.polyfit(xs[sel], line[sel], 2), xs)
    mouth = np.zeros((height, width, 4), np.float32)
    deep = np.array([128, 54, 64], np.float32)
    tooth = np.array([236, 220, 212], np.float32)
    for x in range(width):
        yline = fit[x]
        center = abs((x - width / 2) / (width * 0.46))
        if center >= 1:
            continue
        gap = 16 * (1 - center ** 1.2)
        for y in range(height):
            dy = y - yline
            if dy < -1 or dy > gap + 1.2:
                continue
            if dy < 1.3:
                color = tooth
            else:
                color = deep
            edge = max(0, 1 - center ** 1.15)
            if 0 <= dy <= gap:
                edge = max(edge, 0.85 * (1 - center))
            mouth[y, x, :3] = color
            mouth[y, x, 3] = np.clip(edge, 0, 1) * 255
    # 色だけぼかして、透明画素の黒がにじまないようにする
    alpha = mouth[:, :, 3] / 255
    rgb_m = mouth[:, :, :3]
    premul = rgb_m * alpha[:, :, None]
    premul = cv2.GaussianBlur(premul, (0, 0), 0.6)
    alpha_b = cv2.GaussianBlur(alpha, (0, 0), 0.6)
    safe = alpha_b > 0.02
    rgb_m[safe] = premul[safe] / alpha_b[safe, None]
    mouth[:, :, 3] = alpha_b * 255
    full = np.zeros((rgb.shape[0], rgb.shape[1], 4), np.uint8)
    full[y0:y1, x0:x1] = np.clip(mouth, 0, 255).astype(np.uint8)
    return full, {"x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0}


def layer_of(color, mask):
    image = np.zeros((color.shape[0], color.shape[1], 4), np.uint8)
    image[mask, :3] = color[mask]
    image[mask, 3] = 255
    return image


def fill_under(rgb, hole, sample_down):
    """穴の各列を、すぐ下の画素で埋める。"""
    filled = rgb.copy()
    height, width = hole.shape
    ys, xs = np.where(hole)
    if len(xs) == 0:
        return filled
    for x in np.unique(xs):
        rows = ys[xs == x]
        below = int(rows.max()) + sample_down
        below = min(height - 1, max(0, below))
        if hole[below, x]:
            # 下も穴なら左右の既知の画素を探す
            found = None
            for step in range(1, 40):
                for nx in (x - step, x + step):
                    if 0 <= nx < width and not hole[min(height - 1, below), nx]:
                        found = rgb[min(height - 1, below), nx]
                        break
                if found is not None:
                    break
            color = found if found is not None else rgb[below, x]
        else:
            color = rgb[below, x]
        filled[rows, x] = color
    return filled


def main():
    rgb = np.array(Image.open(SRC).convert("RGB"))
    height, width = rgb.shape[:2]
    red, green, blue = [rgb[:, :, i].astype(np.int16) for i in range(3)]
    lum = rgb.astype(np.float32).mean(axis=2)
    corner = np.median(rgb[:24, :24].reshape(-1, 3), axis=0)
    dist_bg = np.linalg.norm(rgb.astype(np.float32) - corner.astype(np.float32), axis=2)
    background = dist_bg < 28
    character = ~background
    skin = character & (red > 170) & (green > 130) & (blue > 110) & (red > green + 6) & (red > blue + 8)
    white = character & (red > 188) & (green > 182) & (blue > 172) & (np.abs(red - green) < 32)
    # シャツのひだは白の近くの低彩度
    shirt = cv2.dilate(white.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool)
    shirt &= character & ~skin & (np.abs(red - green) < 36) & (np.abs(red - blue) < 48) & (lum > 120)
    white = white | shirt
    blueish = character & ~skin & ~white & (blue > red + 4) & (blue + 8 > green)
    hair = character & ~skin & ~white & ~blueish
    # 髪の縁の暗い画素を髪に戻す
    hair_zone = cv2.dilate(hair.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool)
    hair = hair | (hair_zone & character & ~skin & ~white & (lum < 70))
    blueish = blueish & ~hair
    clothes = (blueish | white) & ~hair

    cheek = np.array([236, 196, 176], np.float32)
    dist_cheek = np.linalg.norm(rgb.astype(np.float32) - cheek, axis=2)
    masks = [eye_mask(rgb, dist_cheek, spec) for spec in EYES]
    eyes = np.zeros((height, width), bool)
    for mask in masks:
        eyes |= mask
    # まつ毛
    lash = cv2.dilate(eyes.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool) & (lum < 80) & character
    eyes = eyes | lash
    hair = hair & ~eyes
    # 顔の輪郭は顔側に残す。髪がずれても、輪郭が砂のように割れない。
    skin_edge = cv2.dilate(skin.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool)
    outline = hair & skin_edge
    hair = hair & ~outline

    bangs = np.zeros((height, width), np.uint8)
    cv2.fillPoly(
        bangs,
        [np.array([(300, 155), (420, 125), (512, 112), (650, 130), (740, 190), (700, 310), (620, 348), (512, 328), (400, 350), (320, 300), (290, 210)], np.int32)],
        1,
    )
    bangs = bangs.astype(bool) & hair
    over_body = hair & cv2.dilate(clothes.astype(np.uint8), np.ones((9, 9), np.uint8)).astype(bool)
    crown = (np.arange(height)[:, None] < 190) & hair & ~bangs
    front = (bangs | over_body) & ~crown
    back = hair & ~front

    # 前髪の下。顔の上は肌、体の上は服。
    face_zone = np.zeros((height, width), np.uint8)
    cv2.ellipse(face_zone, (512, 430), (150, 190), 0, 0, 360, 1, -1)
    face_zone = face_zone.astype(bool)
    bang_hole = front & (face_zone | (np.arange(height)[:, None] < 430))
    body_hole = front & ~bang_hole & (np.arange(height)[:, None] > 560)
    under = fill_under(rgb, bang_hole, 10)
    under = fill_under(under, body_hole, 2)
    skin_color = np.median(rgb[skin], axis=0) if skin.any() else np.array([236, 198, 178])
    under[eyes] = skin_color
    blur = cv2.GaussianBlur(under, (0, 0), 2.4)
    holes = bang_hole | eyes | body_hole
    under = np.where(holes[:, :, None], blur, rgb)

    face = (skin | eyes | bang_hole | outline) & ~front & ~back & ~clothes
    body = (clothes | body_hole) & ~front & ~back & ~face
    # 首の肌は顔側
    face = face | (skin & ~clothes)

    parts = {
        "back-hair": layer_of(rgb, back),
        "body": layer_of(under, body & ~face),
        "face": layer_of(under, face & ~body & ~back & ~front),
        "eyes": layer_of(rgb, eyes),
        "front-hair": layer_of(rgb, front),
    }
    # 顔に載っている目の穴は補完色のまま（目レイヤーが元の瞳）
    eyelids, eye_boxes = paint_eyelids(rgb, masks, EYES)
    mouth, mouth_box = paint_open_mouth(rgb)
    parts["eyelids"] = eyelids
    parts["mouth-open"] = mouth

    OUT.mkdir(parents=True, exist_ok=True)
    for name, image in parts.items():
        save_png(OUT / f"{name}.png", image)

    order = ["back-hair", "body", "face", "eyes", "front-hair"]
    composite = np.zeros_like(rgb)
    covered = np.zeros((height, width), bool)
    for name in order:
        alpha = parts[name][:, :, 3] > 10
        composite[alpha] = parts[name][alpha, :3]
        covered |= alpha
    diff = np.abs(composite.astype(np.int16) - rgb.astype(np.int16)).mean(axis=2)
    diff[~character] = 0
    # 穴は静止時に前髪と目で隠れる
    hidden = (bang_hole | body_hole | eyes) & covered
    shown = character & covered & ~hidden
    print("mean diff on original pixels", float(diff[shown].mean()) if shown.any() else -1)
    print("uncovered", int((character & ~covered).sum()))
    print({name: int((parts[name][:, :, 3] > 0).sum()) for name in parts})

    layout = {
        "width": width,
        "height": height,
        "background": [int(round(v)) for v in corner],
        "eyes": eye_boxes,
        "mouth": mouth_box,
    }
    (OUT / "layout.json").write_text(json.dumps(layout, ensure_ascii=False, indent=2), encoding="utf-8")

    def plate(name, bg):
        image = Image.fromarray(parts[name], "RGBA")
        base = Image.new("RGB", image.size, bg)
        base.paste(image, mask=image.split()[-1])
        return base

    plate("body", (0, 220, 170)).resize((512, 512)).save("/tmp/vp-parts/body.jpg", quality=80)
    plate("face", (90, 170, 230)).resize((512, 512)).save("/tmp/vp-parts/face.jpg", quality=80)
    plate("front-hair", (255, 0, 170)).resize((512, 512)).save("/tmp/vp-parts/front.jpg", quality=80)
    plate("back-hair", (255, 0, 170)).resize((512, 512)).save("/tmp/vp-parts/back.jpg", quality=80)
    show = Image.new("RGB", (width, height), tuple(int(v) for v in corner))
    for name in order:
        image = Image.fromarray(parts[name], "RGBA")
        show.paste(image, mask=image.split()[-1])
    show.resize((640, 640)).save("/tmp/vp-parts/composite.jpg", quality=86)
    talk = show.copy()
    for name in ("mouth-open", "eyelids"):
        image = Image.fromarray(parts[name], "RGBA")
        talk.paste(image, mask=image.split()[-1])
    talk.resize((640, 640)).save("/tmp/vp-parts/talk.jpg", quality=86)
    talk.crop((370, 300, 690, 430)).resize((960, 390)).save("/tmp/vp-parts/talk-eyes.jpg", quality=86)
    talk.crop((440, 460, 620, 560)).resize((540, 300)).save("/tmp/vp-parts/talk-mouth.jpg", quality=86)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
