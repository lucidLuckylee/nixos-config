#!/usr/bin/env python3
"""Crop a region and overlay a labelled coordinate grid in plate pixels.

Tracing a polygon off a plain screenshot means guessing coordinates, which is
how the first hand-traced layers ended up a few pixels out everywhere. With the
grid drawn in the plate's own coordinate system the vertices can just be read
off.

Usage: gridcrop.py X0 Y0 W H [out.jpg] [--src FILE] [--step 50] [--zoom N]
"""
import sys
from PIL import Image, ImageDraw

a = sys.argv[1:]
x0, y0, w, h = (int(a[i]) for i in range(4))
out = a[4] if len(a) > 4 and not a[4].startswith('--') else 'grid.jpg'


def opt(name, default):
    return type(default)(a[a.index(name) + 1]) if name in a else default


src = opt('--src', 'v2.png')
step = opt('--step', 50)
zoom = opt('--zoom', max(1.0, 1000.0 / w))

img = Image.open(src).convert('RGB').crop((x0, y0, x0 + w, y0 + h))
img = img.resize((int(w * zoom), int(h * zoom)), Image.LANCZOS)
d = ImageDraw.Draw(img, 'RGBA')

for x in range(x0 - x0 % step + step, x0 + w, step):
    px = (x - x0) * zoom
    major = x % (step * 4) == 0
    d.line([(px, 0), (px, img.height)], fill=(0, 255, 255, 150 if major else 70),
           width=2 if major else 1)
    d.text((px + 3, 3), str(x), fill=(255, 255, 0))
for y in range(y0 - y0 % step + step, y0 + h, step):
    py = (y - y0) * zoom
    major = y % (step * 4) == 0
    d.line([(0, py), (img.width, py)], fill=(0, 255, 255, 150 if major else 70),
           width=2 if major else 1)
    d.text((3, py + 3), str(y), fill=(255, 255, 0))

img.save(out, quality=92)
print(f'{out}  {x0},{y0} {w}x{h} at {zoom:.2f}x -> {img.width}x{img.height}')
