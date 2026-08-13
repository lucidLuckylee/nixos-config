#!/usr/bin/env python3
"""Read the painted file back and rebuild everything that depends on it.

  layers_paint.png -> snap to the palette -> layers.png
                   -> per-layer previews (so the edit can be checked)
                   -> mask_port.png   the rain matte   (matte3.py)
                   -> mist.png, mask_layer0.png        (uselayers.py)

The old layers.png is kept as layers.prev.png, because the snap is lossy in one
direction only: anything painted a colour that is not in the palette silently
becomes its nearest neighbour.
"""
import os
import shutil
import subprocess
import sys
import numpy as np
from PIL import Image

import layerlib as L

SRC = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1
                         else '~/Downloads/wallpaper-layers/layers_paint.png')
OUT = os.path.expanduser('~/Downloads/wallpaper-layers')

img = Image.open(SRC).convert('RGB')
if img.size != (L.W, L.H):
    sys.exit(f'{SRC} is {img.size[0]}x{img.size[1]}, expected {L.W}x{L.H} — '
             'the paint file must keep the plate resolution')
rgb = np.asarray(img)

new = L.snap(rgb)
old = L.load_layers()

# How far the painted colours sat from the palette. A large max means something
# was painted in a colour that is not a layer, and got silently reassigned.
pal = np.array([L.PALETTE[k] for k in sorted(L.PALETTE)], np.int32)
err = np.sqrt(((rgb.astype(np.int32) - pal[new]) ** 2).sum(-1))
print(f'palette fit: mean {err.mean():.1f}, max {err.max():.0f} (0 = exact)')
if err.max() > 90:
    n = int((err > 90).sum())
    print(f'  WARNING {n} px ({n / err.size * 100:.2f}%) were far from any '
          f'layer colour and got snapped to the nearest one')

changed = new != old
print(f'changed {changed.sum()} px ({changed.mean() * 100:.2f}% of the frame)')
if changed.any():
    for a in sorted(L.NAMES):
        for b in sorted(L.NAMES):
            if a == b:
                continue
            n = int(((old == a) & (new == b)).sum())
            if n > 200:
                print(f'  {n:8d} px  {a} {L.NAMES[a]:9s} -> {b} {L.NAMES[b]}')
else:
    print('  nothing to do')
    sys.exit(0)

shutil.copyfile('layers.png', 'layers.prev.png')
L.save_layers(new)

plate = np.asarray(Image.open('v2.png').convert('RGB'))
L.write_previews(new, plate, OUT)

for step in ('matte3.py', 'uselayers.py'):
    print(f'--- {step}')
    subprocess.run([sys.executable, step], check=True)

print('\nlayers.png, mask_port.png and mist.png are updated.')
print('Re-render with:  OUT=hq6.mp4 ./render5.sh')
print('Install with:    ./install.sh hq6.mp4')
