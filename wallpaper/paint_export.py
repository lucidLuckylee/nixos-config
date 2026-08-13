#!/usr/bin/env python3
"""Turn layers.png into something a human can actually paint on.

Writes three things into ~/Downloads/wallpaper-layers:

  layers_paint.png    one flat saturated colour per layer. THIS is the file to
                      edit. Bucket fill and a hard pencil are all it takes; the
                      importer snaps every pixel back to the nearest palette
                      entry, so a stray antialiased edge costs nothing.
  layers_outline.png  the plate at full brightness with the current layer
                      boundaries drawn on it, for deciding what to change.
  layers.gpl          a GIMP palette, so the six colours are one click away
                      instead of six hex codes to retype.
"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage

import layerlib as L

OUT = os.path.expanduser('~/Downloads/wallpaper-layers')
os.makedirs(OUT, exist_ok=True)

lay = L.load_layers()
rgb = np.asarray(Image.open('v2.png').convert('RGB'))

Image.fromarray(L.to_colour(lay)).save(f'{OUT}/layers_paint.png')

# Outlines over the untouched plate. Each boundary is drawn in the colour of
# the layer it encloses, so the overview and the paint file share a legend.
ol = rgb.copy()
for k in sorted(L.PALETTE):
    sel = lay == k
    if not sel.any():
        continue
    edge = ndimage.binary_dilation(sel, np.ones((3, 3))) & ~sel
    ol[edge] = L.PALETTE[k]
Image.fromarray(ol).save(f'{OUT}/layers_outline.png')

with open(f'{OUT}/layers.gpl', 'w') as f:
    f.write('GIMP Palette\nName: wallpaper layers\nColumns: 6\n#\n')
    for k in sorted(L.PALETTE):
        r, g, b = L.PALETTE[k]
        f.write(f'{r:3d} {g:3d} {b:3d}\t{k} {L.NAMES[k]}\n')

for k in sorted(L.PALETTE):
    r, g, b = L.PALETTE[k]
    print(f'  {k} {L.NAMES[k]:9s} #{r:02x}{g:02x}{b:02x}  {(lay == k).mean() * 100:5.1f}%')
print('wrote layers_paint.png, layers_outline.png, layers.gpl to', OUT)
