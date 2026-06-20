#!/usr/bin/env python3
"""S6.3 — compose a side-by-side size comparison: the OLD big lens (S6.2 vif,
lensRadius 108) vs the NEW V1-size jewel orb (S6.3, lensRadius 60) on the same
deterministic reco image. Output: screenshots/s6_3_compare_size.png."""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHOTS = os.path.join(ROOT, "screenshots")
OLD = os.path.join(SHOTS, "s6_2_vif_reco.png")          # big lens (r=108)
NEW = os.path.join(SHOTS, "s6_3_reco_centre.png")       # small jewel (r=60)
OUT = os.path.join(SHOTS, "s6_3_compare_size.png")

old = Image.open(OLD).convert("RGB")
new = Image.open(NEW).convert("RGB")
# Match heights (same device, but be safe).
h = min(old.height, new.height)
old = old.resize((round(old.width * h / old.height), h))
new = new.resize((round(new.width * h / new.height), h))

gap, band = 24, 64
W = old.width + new.width + gap
H = h + band
canvas = Image.new("RGB", (W, H), (14, 20, 23))
canvas.paste(old, (0, band))
canvas.paste(new, (old.width + gap, band))

draw = ImageDraw.Draw(canvas)
try:
    font = ImageFont.truetype(
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf", 26)
except Exception:
    font = ImageFont.load_default()


def centered(text, x_center, y):
    bb = draw.textbbox((0, 0), text, font=font)
    draw.text((x_center - (bb[2] - bb[0]) / 2, y), text,
              fill=(233, 240, 238), font=font)


centered("AVANT — grande lentille (r=108)", old.width / 2, 18)
centered("APRES — orbe V1 (r=60)", old.width + gap + new.width / 2, 18)
canvas.save(OUT)
print("wrote", OUT, canvas.size)
