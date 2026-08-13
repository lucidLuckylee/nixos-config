#!/usr/bin/env python3
"""Least-squares fit of the porthole opening.

Every version of this ellipse until now was read off a zoomed screenshot by
eye, and each time it was wrong somewhere — first 19px too far right, then with
a bottom that cut layer 0 flat across. By-eye cannot do better here: the
hammock strap, the laundry and the crate all cross the opening, so most of its
boundary is not visible to be read.

Two ideas make the fit work:

  convex hull    occluders only ever REMOVE area from the opening, never add
                 it, so the hull of SAM's mask recovers the true outer boundary
                 even though the mask itself is carved up. Fitting per-row
                 extremes instead fails badly — those extremes are the edges of
                 whatever occluder happens to sit in that row.

  trimming       SAM does add area in one place: below the strap, where the
                 rim's glass reflection reads as more view. Those points are
                 outliers to an ellipse, so fit, drop hull vertices lying more
                 than 12px outside it, and refit until nothing more is dropped.
"""
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from scipy.spatial import ConvexHull

g = np.asarray(Image.open('sam/port_glass.png')) > 127
g = ndimage.binary_opening(g, np.ones((5, 5)))          # drop specks
lab, n = ndimage.label(g)
g = lab == np.bincount(lab.ravel())[1:].argmax() + 1     # largest piece only

ys, xs = np.nonzero(g)
pts = np.stack([xs, ys], 1).astype(float)


def fit(P):
    p = np.array([466.0, 528.0, 194.0, 206.0])
    x, y = P[:, 0], P[:, 1]
    for _ in range(300):
        cx, cy, rx, ry = p
        dx, dy = (x - cx) / rx, (y - cy) / ry
        r = dx ** 2 + dy ** 2 - 1
        J = np.stack([-2 * dx / rx, -2 * dy / ry,
                      -2 * dx ** 2 / rx, -2 * dy ** 2 / ry], 1)
        step, *_ = np.linalg.lstsq(J, -r, rcond=None)
        p = p + step
        if np.abs(step).max() < 1e-10:
            break
    return p


def radial(P, p):
    """Signed distance from the ellipse, in pixels, positive = outside."""
    cx, cy, rx, ry = p
    dx, dy = (P[:, 0] - cx) / rx, (P[:, 1] - cy) / ry
    t = np.hypot(dx, dy)
    scale = np.hypot(rx * dx, ry * dy) / np.maximum(t, 1e-9)
    return (t - 1) * scale


hull = pts[ConvexHull(pts).vertices]
for it in range(12):
    p = fit(hull)
    d = radial(hull, p)
    keep = d < 12
    print(f'  iter {it}: {len(hull)} hull pts, max outside {d.max():6.1f}px, '
          f'dropping {int((~keep).sum())}')
    if keep.all():
        break
    hull = hull[keep]
    hull = hull[ConvexHull(hull).vertices]

cx, cy, rx, ry = p
d = radial(hull, p)
print(f'\nfit  cx={cx:.0f} cy={cy:.0f} rx={rx:.0f} ry={ry:.0f}')
print(f'     left {cx - rx:.0f}  right {cx + rx:.0f}  '
      f'top {cy - ry:.0f}  bottom {cy + ry:.0f}')
print(f'hull residual: mean |{np.abs(d).mean():.1f}|px, max {np.abs(d).max():.1f}px')
print('by eye was: cx=466 cy=528 rx=194 ry=206  (left 272 right 660 top 322 bottom 734)')

im = Image.open('v2.png').convert('RGB')
dr = ImageDraw.Draw(im)
dr.ellipse([466 - 194, 528 - 206, 466 + 194, 528 + 206], outline=(255, 0, 0), width=2)
dr.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], outline=(0, 255, 0), width=2)
im.save('/tmp/_fit.png')
print('overlay: /tmp/_fit.png   red = by eye, green = fitted')
