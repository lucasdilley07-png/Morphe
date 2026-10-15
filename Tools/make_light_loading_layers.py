#!/usr/bin/env python3
"""Cuts Lucas's light loading art (BrandSource/light/loading-screen-light.webp)
into the light appearances of LoadingPlate (waves; lettering, bar and helmet
painted out) and LoadingHelmet (helmet alone, same 458x737 canvas and scale as
the dark one so LaunchSequenceView's constants hold in both modes), plus the
light LaunchHelmet splash. Light-on-white art: nothing is keyed; the helmet is
opaque inside a feathered traced outline.
Run: python3 Tools/make_light_loading_layers.py"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SRC = "BrandSource/light/loading-screen-light.webp"
A = "Morphe/Assets.xcassets"
src = Image.open(SRC).convert("RGB")
a = np.asarray(src).astype(np.float64)
H, W, _ = a.shape

# helmet outline traced from the art
OUTLINE = [(362, 380), (488, 380), (556, 515), (612, 700), (602, 885), (482, 1032),
           (368, 1032), (244, 885), (232, 700), (292, 515)]
sil = Image.new("L", (W, H), 0); ImageDraw.Draw(sil).polygon(OUTLINE, fill=255)

hole_img = sil.filter(ImageFilter.MaxFilter(41))
d = ImageDraw.Draw(hole_img)
d.rounded_rectangle((280, 1022, 570, 1070), radius=20, fill=255)   # light line under the helmet
d.rounded_rectangle((140, 1090, 712, 1210), radius=30, fill=255)   # wordmark
d.rounded_rectangle((200, 1214, 652, 1252), radius=16, fill=255)   # tagline
d.rounded_rectangle((180, 1312, 680, 1362), radius=22, fill=255)   # bar
d.rounded_rectangle((336, 1372, 526, 1408), radius=12, fill=255)   # LOADING...
hard = np.asarray(hole_img).astype(np.float64) / 255

known = (hard < 0.5).astype(np.float64)
def down(x):
    h, w = x.shape[:2]; h2, w2 = (h + 1) // 2, (w + 1) // 2
    p = np.zeros((h2 * 2, w2 * 2) + x.shape[2:]); p[:h, :w] = x
    return p.reshape(h2, 2, w2, 2, *x.shape[2:]).sum(axis=(1, 3))
levels = []; cc = a * known[..., None]; ww = known.copy()
while True:
    levels.append((cc, ww))
    if min(cc.shape[:2]) <= 2: break
    cc, ww = down(cc), down(ww)
fill = levels[-1][0] / np.maximum(levels[-1][1][..., None], 1e-6)
for cc, ww in reversed(levels[:-1]):
    h, w = cc.shape[:2]
    up = np.asarray(Image.fromarray(np.clip(fill, 0, 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)).astype(np.float64)
    own = cc / np.maximum(ww[..., None], 1e-6); t = np.clip(ww, 0, 1)[..., None]
    fill = own * t + up * (1 - t)
fill = np.asarray(Image.fromarray(np.clip(fill, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(20))).astype(np.float64)
feather = np.asarray(hole_img.filter(ImageFilter.GaussianBlur(10))).astype(np.float64) / 255
hole = np.maximum(hard, feather)
plate = a * (1 - hole[..., None]) + fill * hole[..., None]
Image.fromarray(np.clip(plate, 0, 255).astype(np.uint8)).save(f"{A}/LoadingPlate.imageset/LoadingPlate-light.png")

# helmet: same canvas size as the dark layer (458x737), centred on this helmet
CROP = (193, 338, 651, 1075)
mask = sil.filter(ImageFilter.MaxFilter(13)).filter(ImageFilter.GaussianBlur(8))
helm = src.convert("RGBA"); helm.putalpha(mask)
helm = helm.crop(CROP)
helm.save(f"{A}/LoadingHelmet.imageset/LoadingHelmet-light.png")

# light splash helmet: 236 pt wide, 110 pt lift (matches make_launch_splash.py)
WIDTH_PT, LIFT_PT = 236, 110
hpt = round(WIDTH_PT * helm.height / helm.width)
for s in (2, 3):
    canvas = Image.new("RGBA", (WIDTH_PT * s, (hpt + 2 * LIFT_PT) * s), (0, 0, 0, 0))
    canvas.alpha_composite(helm.resize((WIDTH_PT * s, hpt * s), Image.LANCZOS), (0, 0))
    canvas.save(f"{A}/LaunchHelmet.imageset/LaunchHelmet-light@{s}x.png")
print("light loading layers written", helm.size)
