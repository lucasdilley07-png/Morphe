#!/usr/bin/env python3
"""Cuts Lucas's final loading art (BrandSource/loading-screen-final.webp) into
LoadingFinalPlate (the navy field, helmet + type painted out) and
LoadingFinalMark (helmet, glow line, wordmark, TRAIN SMARTER), so the field
can zoom while the mark is drawn smaller. Run: python3 Tools/make_loading_final_layers.py"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SRC = "BrandSource/loading-screen-final.webp"
A = "Morphe/Assets.xcassets"
BOX = (40, 260, 901, 1340)    # helmet top → tagline bottom, with glow room
FEATHER = 70

src = Image.open(SRC).convert("RGB")
a = np.asarray(src).astype(np.float64)
H, W, _ = a.shape

hard = Image.new("L", (W, H), 0)
ImageDraw.Draw(hard).rounded_rectangle(BOX, radius=160, fill=255)
hole = np.asarray(hard).astype(np.float64) / 255

# push-pull fill of the hole from the surrounding field
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
    up = np.asarray(Image.fromarray(np.clip(fill, 0, 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)).astype(np.float64)
    own = cc / np.maximum(ww[..., None], 1e-6); t = np.clip(ww, 0, 1)[..., None]
    fill = own * t + up * (1 - t)
fill = np.asarray(Image.fromarray(np.clip(fill, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(30))).astype(np.float64)
# fully covered over the whole box, feathering OUTSIDE it
soft = np.asarray(hard.filter(ImageFilter.MaxFilter(61)).filter(ImageFilter.GaussianBlur(FEATHER / 2))).astype(np.float64) / 255
plate = a * (1 - soft[..., None]) + fill * soft[..., None]
plate += np.random.default_rng(3).normal(0, 0.8, plate.shape) * soft[..., None]
Image.fromarray(np.clip(plate, 0, 255).astype(np.uint8)).save(f"{A}/LoadingFinalPlate.imageset/LoadingFinalPlate.png")

# the mark: the original pixels inside a feathered box, transparent outside
inner = Image.new("L", (W, H), 0)
x0, y0, x1, y1 = BOX
ImageDraw.Draw(inner).rounded_rectangle((x0 + 50, y0 + 50, x1 - 50, y1 - 50), radius=140, fill=255)
alpha = inner.filter(ImageFilter.GaussianBlur(FEATHER / 2))
mark = src.convert("RGBA"); mark.putalpha(alpha)
mark.crop(BOX).save(f"{A}/LoadingFinalMark.imageset/LoadingFinalMark.png")
print("box", BOX, "mark size", (BOX[2] - BOX[0], BOX[3] - BOX[1]))
