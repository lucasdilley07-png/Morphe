#!/usr/bin/env python3
"""Launch-screen splash generator (Spartan rebrand).

UILaunchScreen draws its image at natural size, centered in the safe
area. This bakes a splash that lands exactly where LaunchSequenceView
draws MorpheLoadingMark(size: 132): the helmet alone (Lucas 2026-10-02:
no glass tile when the app opens), fitted in the same 132pt box and
lifted above center by the height of the wordmark block below it, so the
system splash hands off to the in-app launch beat without a jump.

One appearance: the icy helmet with its white glow on the solid brand
blue (LaunchField), matching MorpheHelmetMark on the brand field.

Run:  python3 Tools/make_launch_splash.py
"""
from pathlib import Path
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Morphe/Assets.xcassets/HelmetMark.imageset/HelmetMark.png"
OUT = ROOT / "Morphe/Assets.xcassets/LaunchHelmet.imageset"

MARK_PT = 132          # MorpheLoadingMark(size: 132)
LIFT_PT = 46           # half the wordmark + message block under the mark
CANVAS_PT = (MARK_PT, MARK_PT + 2 * LIFT_PT)
BRAND_BLUE = (41, 87, 217, 255)   # #2957D9

def render(scale: int) -> Image.Image:
    helmet = Image.open(SOURCE).convert("RGBA")
    box = MARK_PT * scale
    ratio = min(box / helmet.width, box / helmet.height)
    size = (round(helmet.width * ratio), round(helmet.height * ratio))
    helmet = helmet.resize(size, Image.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS_PT[0] * scale, CANVAS_PT[1] * scale), (0, 0, 0, 0))
    at = ((box - size[0]) // 2, (box - size[1]) // 2)
    # The same soft white glow MorpheHelmetMark draws on the brand field.
    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    glow.paste(Image.new("RGBA", size, (255, 255, 255, 140)), at, helmet)
    glow = glow.filter(ImageFilter.GaussianBlur(10 * scale))
    canvas.alpha_composite(glow)
    canvas.paste(helmet, at, helmet)
    return canvas

OUT.mkdir(parents=True, exist_ok=True)
for old in OUT.glob("*.png"):
    old.unlink()
images = [{"idiom": "universal", "scale": "1x"}]
for scale in (2, 3):
    name = f"LaunchHelmet@{scale}x.png"
    render(scale).save(OUT / name, optimize=True)
    images.append({"filename": name, "idiom": "universal", "scale": f"{scale}x"})
import json
(OUT / "Contents.json").write_text(json.dumps(
    {"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
print("wrote", OUT)
