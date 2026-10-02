#!/usr/bin/env python3
"""Launch-screen splash generator (Spartan rebrand).

UILaunchScreen draws its image at natural size, centered in the safe
area. This bakes a splash that lands exactly where LaunchSequenceView
draws MorpheLoadingMark(size: 132): the helmet alone (Lucas 2026-10-02:
no glass tile when the app opens), fitted in the same 132pt box and
lifted above center by the height of the wordmark block below it, so the
system splash hands off to the in-app launch beat without a jump.

Two appearances, matching MorpheHelmetMark: a brand-blue silhouette on
the white launch field, the icy helmet on the dark one.

Run:  python3 Tools/make_launch_splash.py
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Morphe/Assets.xcassets/HelmetMark.imageset/HelmetMark.png"
OUT = ROOT / "Morphe/Assets.xcassets/LaunchSplash.imageset"

MARK_PT = 132          # MorpheLoadingMark(size: 132)
LIFT_PT = 46           # half the wordmark + message block under the mark
CANVAS_PT = (MARK_PT, MARK_PT + 2 * LIFT_PT)
BRAND_BLUE = (41, 87, 217, 255)   # #2957D9

def render(scale: int, dark: bool) -> Image.Image:
    helmet = Image.open(SOURCE).convert("RGBA")
    box = MARK_PT * scale
    ratio = min(box / helmet.width, box / helmet.height)
    size = (round(helmet.width * ratio), round(helmet.height * ratio))
    helmet = helmet.resize(size, Image.LANCZOS)
    if not dark:
        tint = Image.new("RGBA", size, BRAND_BLUE)
        tint.putalpha(helmet.getchannel("A"))
        helmet = tint
    canvas = Image.new("RGBA", (CANVAS_PT[0] * scale, CANVAS_PT[1] * scale), (0, 0, 0, 0))
    canvas.paste(helmet, ((box - size[0]) // 2, (box - size[1]) // 2), helmet)
    return canvas

OUT.mkdir(parents=True, exist_ok=True)
for old in OUT.glob("*.png"):
    old.unlink()
images = [{"idiom": "universal", "scale": "1x"}]
for dark in (False, True):
    for scale in (2, 3):
        name = f"LaunchSplash{'-dark' if dark else ''}@{scale}x.png"
        render(scale, dark).save(OUT / name, optimize=True)
        entry = {"filename": name, "idiom": "universal", "scale": f"{scale}x"}
        if dark:
            entry = {"appearances": [{"appearance": "luminosity", "value": "dark"}], **entry}
        images.append(entry)
import json
(OUT / "Contents.json").write_text(json.dumps(
    {"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
print("wrote", OUT)
