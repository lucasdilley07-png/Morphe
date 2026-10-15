#!/usr/bin/env python3
"""Cuts Lucas's light-mode Hey Morphe orb (BrandSource/light/hey-morphe-orb-light.webp)
into the light appearances of MorpheAIOrbBase (orb, helmet painted out) and
MorpheAIHelmet (helmet alone) on the same 1024 canvas, so MorpheOrbView's
helmet-moves-with-the-voice animation runs unchanged in light mode.
Light art is light-on-white, so nothing is keyed: both layers are opaque
inside feathered masks. Run: python3 Tools/make_light_orb_layers.py"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SRC = "BrandSource/light/hey-morphe-orb-light.webp"
A = "Morphe/Assets.xcassets"
CX, CY, R = 621, 622, 546
N = 1024

src = Image.open(SRC).convert("RGB").crop((CX - R, CY - R, CX + R, CY + R)).resize((N, N), Image.LANCZOS)
a = np.asarray(src).astype(np.float64)
L = a.mean(2)

# helmet outline traced from the art (source coords) — the light helmet's
# glass rims are as pale as the orb, so a threshold can't separate it
OUTLINE = [(560, 306), (688, 306), (768, 440), (806, 585), (800, 800), (680, 938),
           (570, 938), (446, 800), (440, 585), (478, 440)]
k = N / (2 * R)
def c(x, y): return (x - (CX - R)) * k, (y - (CY - R)) * k
hull = Image.new("L", (N, N), 0); ImageDraw.Draw(hull).polygon([c(x, y) for x, y in OUTLINE], fill=255)
helm = hull.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(8))      # glass rims + glow
hole = np.asarray(hull.filter(ImageFilter.MaxFilter(31))).astype(np.float64) / 255

# push-pull fill of the hole for the base
known = (hole < 0.5).astype(np.float64)
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
    upi = np.asarray(Image.fromarray(np.clip(fill, 0, 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)).astype(np.float64)
    own = cc / np.maximum(ww[..., None], 1e-6); t = np.clip(ww, 0, 1)[..., None]
    fill = own * t + upi * (1 - t)
fill = np.asarray(Image.fromarray(np.clip(fill, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(14))).astype(np.float64)
feather = np.asarray(Image.fromarray((hole * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(10))).astype(np.float64) / 255
base_rgb = a * (1 - feather[..., None]) + fill * feather[..., None]

circle = Image.new("L", (N * 4, N * 4), 0); ImageDraw.Draw(circle).ellipse((24, 24, N * 4 - 24, N * 4 - 24), fill=255)
circle = circle.resize((N, N), Image.LANCZOS).filter(ImageFilter.GaussianBlur(2))

base = Image.fromarray(np.clip(base_rgb, 0, 255).astype(np.uint8)).convert("RGBA"); base.putalpha(circle)
base.save(f"{A}/MorpheAIOrbBase.imageset/MorpheAIOrbBase-light.png")
hl = src.convert("RGBA"); hl.putalpha(Image.fromarray(np.minimum(np.asarray(helm), np.asarray(circle))))
hl.save(f"{A}/MorpheAIHelmet.imageset/MorpheAIHelmet-light.png")
print("light orb layers written")
