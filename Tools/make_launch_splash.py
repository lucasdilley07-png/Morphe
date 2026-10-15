#!/usr/bin/env python3
"""Launch-screen splash generator (loading screen, 2026-10-15).

UILaunchScreen draws its image at natural size, centred in the WHOLE
screen (UIImageRespectsSafeAreaInsets = false) on the LaunchField navy.
This bakes the glass helmet from Lucas's loading art (LoadingHelmet) at
the size LaunchSequenceView draws it (LoadingHelmet.width, 236 pt) with
LIFT_PT of empty canvas underneath, so its centre lands LIFT_PT above
screen centre — exactly where the in-app loading screen puts it. The
waves then fade in around a helmet that never moves.

Run:  python3 Tools/make_launch_splash.py
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Morphe/Assets.xcassets/LoadingHelmet.imageset/LoadingHelmet.png"
OUT = ROOT / "Morphe/Assets.xcassets/LaunchHelmet.imageset"

WIDTH_PT = 236   # LoadingHelmet.width
LIFT_PT = 110    # LoadingHelmet.lift


def render(scale: int) -> Image.Image:
    helmet = Image.open(SOURCE).convert("RGBA")
    height_pt = round(WIDTH_PT * helmet.height / helmet.width)
    canvas = Image.new("RGBA", (WIDTH_PT * scale, (height_pt + 2 * LIFT_PT) * scale), (0, 0, 0, 0))
    canvas.alpha_composite(helmet.resize((WIDTH_PT * scale, height_pt * scale), Image.LANCZOS), (0, 0))
    return canvas


if __name__ == "__main__":
    for scale in (2, 3):
        render(scale).save(OUT / f"LaunchHelmet@{scale}x.png")
    print("LaunchHelmet written")
