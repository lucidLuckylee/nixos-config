#!/usr/bin/env python3
"""Rain matte from the exact porthole boundary.

matte3.py built this as `(layer 0) AND (ellipse inset by 15px)`. Both halves
were approximations. The inset existed only to keep rain off the rim, whose
reflections the colour test read as sky, and it paid for that with a ring of
real view all the way round. Layer 0 came from a connectivity test on colour,
so its edges were as good as that test's, which is to say blocky.

sam_port.py returns the opening with an exact outer edge — the rim excluded,
taken from the artwork rather than from a nominal ellipse. But it is the
opening *including* what hangs in it: measured against it, 68% of the laundry
and 91% of the bundle came back as "opening". So it supplies the outer boundary
only, and the occluders still come from layer 0, which is the connectivity test
and already knows the laundry, rope and bundle are room.

    rain = (exact opening from SAM) AND (layer 0)

Each side does what it is good at: SAM has the precise silhouettes, the
connectivity test has the room/view distinction that no silhouette implies.

What is left to do is cleanup, and it is deliberately conservative:

  clip        to the nominal ellipse grown by 10px, which removes stray specks
              SAM left on the machinery outside the porthole without trimming
              the opening itself (the true boundary sits inside this).
  despeckle   drop components under 300px and fill holes under 200px. These are
              single-pixel artefacts, not real occluders — the laundry is 16850px
              and the rope 1325px, so nothing genuine is anywhere near the cut.
  hard edge   antialias with a small blur, then re-harden. A feathered occluder
              makes a streak fade out as it approaches, which reads as the rain
              dying rather than as something standing in front of it.
"""
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

W, H = 1920, 1080
CX, CY, RX, RY = 466, 543, 194, 221     # re-fitted; see layers3.py
# No slack. GROW was 10 while the ellipse was known to be approximate. Now that
# it is fitted to the opening, growing it just lets rain back onto the rim,
# which is the artefact this whole matte exists to avoid.
GROW = 0

opening = np.asarray(Image.open('sam/port_glass.png')) > 127
lay = np.asarray(Image.open('layers.png'))
m = opening & (lay == 0)
raw = int(m.sum())

lim = Image.new('L', (W, H), 0)
ImageDraw.Draw(lim).ellipse([CX - RX - GROW, CY - RY - GROW,
                             CX + RX + GROW, CY + RY + GROW], fill=255)
m &= np.asarray(lim) > 0
clipped = int(m.sum())

lab, n = ndimage.label(m)
if n:
    keep = np.flatnonzero(np.bincount(lab.ravel())[1:] >= 300) + 1
    m = np.isin(lab, keep)
holes = ndimage.binary_fill_holes(m) & ~m
lab, n = ndimage.label(holes)
if n:
    small = np.flatnonzero(np.bincount(lab.ravel())[1:] < 200) + 1
    m |= np.isin(lab, small)

a = ndimage.gaussian_filter(m.astype(np.float32), 0.6)
a = np.clip((a - 0.35) / 0.3, 0, 1)
Image.fromarray((a * 255).astype(np.uint8)).save('mask_port.png')

ell = Image.new('L', (W, H), 0)
ImageDraw.Draw(ell).ellipse([CX - RX, CY - RY, CX + RX, CY + RY], fill=255)
ell = np.asarray(ell) > 0
final = a > 0.5
print(f'sam {raw}px -> clipped {clipped} -> final {int(final.sum())}px '
      f'({final.sum() / ell.sum():.0%} of the nominal aperture)')
print(f'outside the nominal ellipse: {int((final & ~ell).sum())}px')
