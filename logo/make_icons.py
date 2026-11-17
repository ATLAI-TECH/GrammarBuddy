"""Cut the logo sources into the files the app uses.

    python3 logo/make_icons.py          (run from the repository root; needs Pillow and numpy)

Sources (logo/source/):
    branding-board.png     the colour mark, the wordmark, an app-icon mock-up and three black glyphs
    menu-bar-states.png    the three menu-bar glyphs drawn at menu-bar size (simplified shapes)
Outputs:
    logo/cut/…                                         every piece, for the README, the website, etc.
    GrammarBuddy/Resources/Assets.xcassets/AppIcon     the app icon, all macOS sizes
    GrammarBuddy/Resources/Assets.xcassets/MenuBar*    template images for the status item (1x, 2x, 3x)
"""
import json, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "logo", "source")
CUT = os.path.join(ROOT, "logo", "cut")
ASSETS = os.path.join(ROOT, "GrammarBuddy", "Resources", "Assets.xcassets")
BOARD = Image.open(os.path.join(SRC, "branding-board.png")).convert("RGB")
MENU = Image.open(os.path.join(SRC, "menu-bar-states.png")).convert("RGB")

# Boxes found by looking for everything that differs from the background (see docs/5_…).
MARK = (135, 138, 530, 470)            # colour mark on the board; the wordmark starts at x≈518 below y≈240
WORDMARK = (512, 250, 1432, 395)
BOARD_GLYPHS = {"normal": (570, 645, 767, 827), "paused": (871, 645, 1060, 827), "dot": (1153, 645, 1370, 827)}
# Menu-bar glyphs: same canvas for the three states so the "G" keeps its size and place when the state changes.
MENU_BOTTOM, MENU_W, MENU_H = 544, 144, 130
MENU_LEFT = {"normal": 163, "paused": 459, "dot": 718}


def cut_out_background(img, tolerance=14, soft=26):
    """RGBA copy with the flat background made transparent. Only background connected to the border is removed,
    so white inside the mark stays white. Edge pixels get partial alpha from how far they are from the background."""
    rgb = np.asarray(img).astype(np.int32)
    bg = np.median(np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]]), axis=0)
    dist = np.abs(rgb - bg).max(axis=2)
    near = dist <= soft
    # flood fill from the border through pixels close to the background colour
    h, w = dist.shape
    seen = np.zeros((h, w), bool)
    stack = [(y, x) for y in range(h) for x in (0, w - 1)] + [(y, x) for x in range(w) for y in (0, h - 1)]
    while stack:
        y, x = stack.pop()
        if y < 0 or x < 0 or y >= h or x >= w or seen[y, x] or not near[y, x]:
            continue
        seen[y, x] = True
        stack += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
    alpha = np.where(seen, np.clip((dist - tolerance) / float(soft - tolerance), 0, 1), 1.0)
    out = np.dstack([rgb, (alpha * 255).round()]).astype(np.uint8)
    return Image.fromarray(out)


def colour_mark():
    crop = BOARD.crop(MARK)
    # paint over the first letter of the wordmark that reaches into the box
    d = ImageDraw.Draw(crop)
    d.rectangle([WORDMARK[0] - MARK[0] - 8, 240 - MARK[1], crop.width, crop.height], fill=BOARD.getpixel((5, 5)))
    rgba = cut_out_background(crop)
    return rgba.crop(rgba.getbbox())


def template(img, box):
    """A black glyph on a flat light background → black with alpha (a macOS template image)."""
    g = np.asarray(img.crop(box).convert("L")).astype(np.float64)
    bg = np.median(np.concatenate([g[0], g[-1], g[:, 0], g[:, -1]]))
    ink = np.percentile(g, 1)
    a = np.clip((bg - 6 - g) / max(1.0, bg - 6 - ink - 10), 0, 1)
    out = np.zeros(g.shape + (4,), np.uint8)
    out[..., 3] = (a * 255).round()
    return Image.fromarray(out)


def app_icon(mark, size=1024):
    """macOS icon grid: an 824-point rounded square on a 1024 canvas, soft shadow below, the mark centred."""
    s = 4                                           # supersample for a smooth edge
    big = size * s
    plate = Image.new("L", (big, big), 0)
    m = 100 * s
    ImageDraw.Draw(plate).rounded_rectangle([m, m, big - m, big - m], radius=185 * s, fill=255)
    plate = plate.resize((size, size), Image.LANCZOS)
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sh = Image.new("L", (size, size), 0)
    sh.paste(plate.point(lambda v: int(v * 0.30)), (0, 12))
    shadow.putalpha(sh.filter(ImageFilter.GaussianBlur(14)))
    # white plate with a very light top-to-bottom tint, as on the board
    grad = np.linspace(255, 244, size).reshape(-1, 1).repeat(size, 1)
    face = np.dstack([grad, grad, np.clip(grad + 4, 0, 255), np.full((size, size), 255)]).astype(np.uint8)
    face = Image.fromarray(face); face.putalpha(plate)
    icon = Image.alpha_composite(shadow, face)
    target = 600                                    # longest side of the mark inside the 824 plate
    k = target / max(mark.size)
    m2 = mark.resize((round(mark.width * k), round(mark.height * k)), Image.LANCZOS)
    icon.alpha_composite(m2, ((size - m2.width) // 2 + 6, (size - m2.height) // 2))
    return icon


def write_app_icon(icon):
    d = os.path.join(ASSETS, "AppIcon.appiconset"); os.makedirs(d, exist_ok=True)
    images = []
    for pt in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            px = pt * scale; name = f"icon_{pt}x{pt}{'@2x' if scale == 2 else ''}.png"
            icon.resize((px, px), Image.LANCZOS).save(os.path.join(d, name))
            images.append({"idiom": "mac", "size": f"{pt}x{pt}", "scale": f"{scale}x", "filename": name})
    json.dump({"images": images, "info": {"version": 1, "author": "xcode"}}, open(os.path.join(d, "Contents.json"), "w"), indent=2)


def write_menu_icon(name, glyph):
    d = os.path.join(ASSETS, f"{name}.imageset"); os.makedirs(d, exist_ok=True)
    images = []
    for scale in (1, 2, 3):
        f = f"{name}{'' if scale == 1 else f'@{scale}x'}.png"
        glyph.resize((20 * scale, 18 * scale), Image.LANCZOS).save(os.path.join(d, f))
        images.append({"idiom": "universal", "scale": f"{scale}x", "filename": f})
    json.dump({"images": images, "info": {"version": 1, "author": "xcode"},
               "properties": {"template-rendering-intent": "template"}}, open(os.path.join(d, "Contents.json"), "w"), indent=2)


def main():
    os.makedirs(CUT, exist_ok=True); os.makedirs(ASSETS, exist_ok=True)
    json.dump({"info": {"version": 1, "author": "xcode"}}, open(os.path.join(ASSETS, "Contents.json"), "w"), indent=2)
    mark = colour_mark(); mark.save(os.path.join(CUT, "mark.png"))
    wm = cut_out_background(BOARD.crop(WORDMARK)); wm.crop(wm.getbbox()).save(os.path.join(CUT, "wordmark.png"))
    icon = app_icon(mark); icon.save(os.path.join(CUT, "app-icon-1024.png")); write_app_icon(icon)
    for state, box in BOARD_GLYPHS.items():
        g = template(BOARD, box); g.crop(g.getbbox()).save(os.path.join(CUT, f"glyph-detailed-{state}.png"))
    for state, left in MENU_LEFT.items():
        g = template(MENU, (left, MENU_BOTTOM - MENU_H, left + MENU_W, MENU_BOTTOM))
        g.save(os.path.join(CUT, f"menubar-{state}.png"))
        write_menu_icon("MenuBar" + state.capitalize(), g)
    # contact sheet to check the result by eye: light and dark menu bars, icon sizes
    sheet = Image.new("RGBA", (1100, 560), (236, 238, 244, 255))
    sheet.alpha_composite(icon.resize((384, 384), Image.LANCZOS), (10, 10))
    for i, px in enumerate((128, 64, 32, 16)):
        sheet.alpha_composite(icon.resize((px, px), Image.LANCZOS), (410 + i * 30 + sum((128, 64, 32, 16)[:i]), 30))
    ImageDraw.Draw(sheet).rectangle([400, 220, 1100, 300], fill=(30, 30, 34, 255))
    x = 420
    for bar_y, colour in ((330, (0, 0, 0)), (238, (255, 255, 255))):
        x = 420
        for state in MENU_LEFT:
            for scale in (1, 2, 3):
                g = Image.open(os.path.join(ASSETS, f"MenuBar{state.capitalize()}.imageset", f"MenuBar{state.capitalize()}{'' if scale == 1 else f'@{scale}x'}.png"))
                tint = Image.new("RGBA", g.size, colour + (255,)); tint.putalpha(g.getchannel("A"))
                sheet.alpha_composite(tint, (x, bar_y)); x += g.width + 14
            x += 20
    dark = Image.new("RGBA", (300, 150), (24, 24, 28, 255)); dark.alpha_composite(mark.resize((round(mark.width * 0.3), round(mark.height * 0.3)), Image.LANCZOS), (20, 20))
    sheet.alpha_composite(dark, (20, 400))
    sheet.save(os.path.join(CUT, "_check.png"))


if __name__ == "__main__":
    main()
