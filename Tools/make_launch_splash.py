#!/usr/bin/env python3
"""Launch-screen splash generator (Spartan rebrand, 2026-10-01).

UILaunchScreen draws its image at natural size, centered. The 1024px
LaunchMark at 1x rendered 1024pt wide — a cropped blue wall on every
phone (audit 28, P1). This bakes a dedicated splash that lands exactly
where LaunchSequenceView draws MorpheLoadingMark(size: 132): same 132pt
tile, same 22% corner radius, lifted above center by the height of the
wordmark block below it, so the system splash hands off to the in-app
launch beat without a jump.

Run:  python3 Tools/make_launch_splash.py
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Morphe/Assets.xcassets/LaunchMark.imageset/LaunchMark.png"
OUT = ROOT / "Morphe/Assets.xcassets/LaunchSplash.imageset"

MARK_PT = 132          # MorpheLoadingMark(size: 132)
LIFT_PT = 46           # half the wordmark + message block under the mark
CANVAS_PT = (MARK_PT, MARK_PT + 2 * LIFT_PT)
RADIUS = 0.22          # clipShape(RoundedRectangle(cornerRadius: size * 0.22))
SUPERSAMPLE = 4

def render(scale: int) -> Image.Image:
    side = MARK_PT * scale
    mark = Image.open(SOURCE).convert("RGBA").resize((side, side), Image.LANCZOS)
    big = side * SUPERSAMPLE
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, big - 1, big - 1), radius=int(big * RADIUS), fill=255)
    mask = mask.resize((side, side), Image.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS_PT[0] * scale, CANVAS_PT[1] * scale), (0, 0, 0, 0))
    canvas.paste(mark, (0, 0), mask)
    return canvas

OUT.mkdir(parents=True, exist_ok=True)
for scale in (2, 3):
    render(scale).save(OUT / f"LaunchSplash@{scale}x.png", optimize=True)
(OUT / "Contents.json").write_text("""{
  "images" : [
    {
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "filename" : "LaunchSplash@2x.png",
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "filename" : "LaunchSplash@3x.png",
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
""")
print("wrote", OUT)
