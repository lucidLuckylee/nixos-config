#!/usr/bin/env python3
"""Procedural raindrops on the porthole glass.

The drops used to be a crop of a stock rain-on-window clip. At the size we want
them — about 1/15 of the source — no crop is big enough to fill the opening, so
it had to be tiled, and a tiled 131px cell repeated nine times is visible as a
grid no matter how it is mirrored or how many extra layers are blended over it.
Superimposing a second tiling at a coprime scale hides the seams but not the
repeat, because the same cell is still there nine times.

Generating the drops instead removes the constraint entirely: every drop is
placed independently, so there is nothing to repeat. It also removes the last
third-party asset from the render — the clip was CC BY-SA, which meant
attribution and share-alike on anything built from it.

Three outputs, all 1920x1080 so the filtergraph does not have to position them:

  drops_x.png, drops_y.png   displacement maps for ffmpeg's `displace`. 128 is
                             "no shift", so everything outside a drop is flat
                             grey and only the drops bend the view behind them.
                             A drop is modelled as a lens that inverts what is
                             behind it: sample from the opposite side of the
                             centre, magnified, which is what a real droplet on
                             a window does.
  drops_spec.png             RGBA. The part refraction cannot give you: the
                             specular glint, the shading across the body, and
                             the dark seating ring where the drop meets glass.

Drop sizes follow a heavy-tailed mix — mostly tiny, a few large — because a
window that has been rained on has exactly that: a fine mist of small drops
with occasional fat ones that have run and merged.
"""
import numpy as np
from PIL import Image

W, H = 1920, 1080
# The opening, plus a margin. Drops outside it are wasted work: the whole layer
# is masked by mask_port.png at composite time.
X0, Y0, X1, Y1 = 262, 312, 672, 772
RNG = np.random.default_rng(20250812)

# (count, min radius, max radius) — heavy tail
POPULATIONS = [(5600, 0.7, 1.5), (1900, 1.5, 2.6), (430, 2.6, 4.2), (60, 4.2, 6.5)]
INVERT = 1.25         # lens strength: how far across the drop the view is bent
LIGHT = np.array([-0.42, -0.48])      # highlight direction, up and to the left

xmap = np.full((H, W), 128.0)
ymap = np.full((H, W), 128.0)
spec = np.zeros((H, W, 4))            # RGBA, premultiplied later


def place(cx, cy, r):
    # Larger drops sag: gravity stretches them vertically and they sit lower.
    sag = 1.0 + 0.28 * min(r / 6.5, 1.0)
    x0, x1 = int(cx - r - 3), int(cx + r + 4)
    y0, y1 = int(cy - r * sag - 3), int(cy + r * sag + 4)
    if x0 < 0 or y0 < 0 or x1 > W or y1 > H:
        return
    yy, xx = np.mgrid[y0:y1, x0:x1]
    dx = (xx - cx) / r
    dy = (yy - cy) / (r * sag)
    d2 = dx ** 2 + dy ** 2
    inside = d2 < 1.0
    if not inside.any():
        return

    # --- refraction -------------------------------------------------------
    # Sample from the far side of the drop, easing to zero at the rim so the
    # edge does not tear. displace() reads output(x,y) = input(x+xm-128, ...).
    ease = np.sqrt(np.clip(1.0 - d2, 0, 1))
    ox = -INVERT * (xx - cx) * ease
    oy = -INVERT * (yy - cy) * ease
    xmap[y0:y1, x0:x1] = np.where(inside, 128.0 + ox, xmap[y0:y1, x0:x1])
    ymap[y0:y1, x0:x1] = np.where(inside, 128.0 + oy, ymap[y0:y1, x0:x1])

    # --- shading ----------------------------------------------------------
    # Hemisphere normal, lit from up-left: the body picks up a gentle gradient
    # and the lower-right rim goes dark where the glass shows through.
    nz = np.sqrt(np.clip(1.0 - d2, 1e-6, 1))
    lam = np.clip(-(dx * LIGHT[0] + dy * LIGHT[1]) / max(np.hypot(*LIGHT), 1e-6), -1, 1)
    body = np.clip(0.085 * lam + 0.05 * nz, -0.13, 0.18)

    # Specular glint: small, offset toward the light, sharper on bigger drops.
    sx, sy = cx + LIGHT[0] * r * 0.62, cy + LIGHT[1] * r * sag * 0.62
    sr = max(0.55, r * 0.24)
    sd2 = ((xx - sx) ** 2 + (yy - sy) ** 2) / sr ** 2
    glint = np.exp(-2.6 * sd2) * (0.30 + 0.22 * min(r / 6.0, 1.0))

    # Seating ring: a thin darkening just inside the rim.
    ring = np.exp(-((np.sqrt(d2) - 0.95) ** 2) / 0.004) * 0.10

    lum = body + glint - ring
    alpha = np.clip(np.abs(lum) * 1.6, 0, 1) * inside
    col = np.clip(0.5 + lum, 0, 1)

    tgt = spec[y0:y1, x0:x1]
    # Painter's-algorithm compositing, so overlapping drops stack sensibly.
    a = alpha[..., None]
    tgt[..., :3] = tgt[..., :3] * (1 - a) + np.dstack([col, col, col]) * a
    tgt[..., 3] = np.clip(tgt[..., 3] * (1 - alpha) + alpha, 0, 1)


total = 0
for count, rmin, rmax in POPULATIONS:
    for _ in range(count):
        r = RNG.uniform(rmin, rmax)
        cx = RNG.uniform(X0, X1)
        cy = RNG.uniform(Y0, Y1)
        place(cx, cy, r)
        total += 1

Image.fromarray(np.clip(xmap, 0, 255).astype(np.uint8)).save('drops_x.png')
Image.fromarray(np.clip(ymap, 0, 255).astype(np.uint8)).save('drops_y.png')
rgba = np.dstack([np.clip(spec[..., :3], 0, 1) * 255, np.clip(spec[..., 3], 0, 1) * 255])
Image.fromarray(rgba.astype(np.uint8), 'RGBA').save('drops_spec.png')

cov = (spec[..., 3] > 0.02).sum() / ((X1 - X0) * (Y1 - Y0))
print(f'{total} drops, {cov:.0%} of the opening covered')
print(f'displacement range {xmap.min() - 128:.0f}..{xmap.max() - 128:.0f}px')
