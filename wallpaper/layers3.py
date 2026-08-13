#!/usr/bin/env python3
"""Assign every pixel to a depth layer. Third pass.

What changed from layers2.py:

  the depth source  Depth Anything V2 Large, ensembled over three input scales
                    (depth2.py). The Small model put the entire ceiling in the
                    far band, which is why the overhead pipes, the globe and
                    the hanging planes all came out as mid-room.

  the band edges    chosen by measuring the new depth at named landmarks rather
                    than by eye. The values in EDGES fall in the gaps between
                    clusters, so a small error in the depth cannot move an
                    object across a boundary:

                      back wall / centre machinery / neon panels   0.21-0.22
                      ----------------------------------- 0.235
                      ceiling, orange pipe, floor, washer          0.26-0.33
                      ----------------------------------- 0.34
                      globe, hanging planes, dresser, teal cloth   0.35-0.42
                      ----------------------------------- 0.47
                      hammock and its straps                       0.57
                      ----------------------------------- 0.70
                      the drape and straps hanging at top right    0.83

  the ordering      the despeckle runs on the depth bands alone. layers2.py
                    median-filtered after stamping the traced polygons, which
                    rounded off their corners.

Layer 0 is not a depth band. It comes from the connectivity test, because a
depth model cannot tell that laundry hanging in the opening belongs to the room
while the lit doorway seen through it does not.
"""
import os
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

import layerlib as L

W, H = L.W, L.H
# The porthole: left 272, right 660, top 322, bottom 764.
#
# Two corrections from the original 485,540,196,212, which was measured by eye.
# It sat ~19px too far right, so rain ran past the opening onto the rim. And it
# was ~30px short at the bottom, which showed up as a flat horizontal edge
# where layer 0 was cut off mid-view.
#
# fit_port.py fits this properly — convex hull of SAM's mask, since occluders
# only ever remove area from the opening — but its answer is pulled outwards by
# the one place SAM over-reads, the rim's reflection below the hammock strap.
# So the fit is used as a check on the extremes rather than taken wholesale.
CX, CY, RX, RY = 466, 543, 194, 221
EDGES = [0.235, 0.34, 0.47, 0.70]          # 4 edges -> bands 1..5

rgb = np.asarray(Image.open('v2.png').convert('RGB'), dtype=np.uint8)
d = np.load('depth.npy')

lay = (np.digitize(d, EDGES) + 1).astype(np.uint8)
lay = ndimage.median_filter(lay, size=5)   # despeckle the bands, not the traces


def poly(*pts):
    m = Image.new('L', (W, H), 0)
    ImageDraw.Draw(m).polygon(list(pts), fill=255)
    return np.asarray(m) > 0


def ellipse(cx, cy, rx, ry):
    m = Image.new('L', (W, H), 0)
    ImageDraw.Draw(m).ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=255)
    return np.asarray(m) > 0


def polyline(pts, width):
    m = Image.new('L', (W, H), 0)
    ImageDraw.Draw(m).line(list(pts), fill=255, width=width, joint='curve')
    return np.asarray(m) > 0


def sam(name):
    """A mask from sam_masks.py. These replace the hand-traced polygons: SAM
    reads the object's real edge out of the image, where tracing meant reading
    vertices off a zoomed screenshot and produced visibly rectangular cloth."""
    return np.asarray(Image.open(f'sam/{name}.png')) > 127


def fill_line(mask, width=5):
    """Bridge the gaps in a segmented rope or cord.

    SAM finds a thin line in fragments — it drops out where something crosses
    it and where it fades into its background — so it covers about 58% of the
    clothesline's span. The fragments it does return are accurate, though, so
    fitting a quadratic through their per-column centres and redrawing gives a
    continuous line that still comes from the image rather than from my guess.
    """
    # Fit along the dominant axis. The clothesline runs across the frame, so
    # y = f(x); the cords hang, so x = f(y). Fitting the wrong way round is
    # degenerate — a vertical cord has one x for many y.
    ys_all, xs_all = np.nonzero(mask)
    if len(xs_all) < 60:
        return mask
    vertical = np.ptp(ys_all) > np.ptp(xs_all)     # ndarray.ptp is gone in numpy 2
    u_all, v_all = (ys_all, xs_all) if vertical else (xs_all, ys_all)
    u = np.unique(u_all)
    if len(u) < 20:
        return mask
    v = np.array([v_all[u_all == k].mean() for k in u])
    fit = np.poly1d(np.polyfit(u, v, 2))
    resid = np.abs(v - fit(u))
    keep = resid < max(4.0, 3 * np.median(resid))       # drop outlier slices
    if keep.sum() < 10:
        return mask
    fit = np.poly1d(np.polyfit(u[keep], v[keep], 2))
    span = np.arange(u.min(), u.max() + 1)
    pts = list(zip(fit(span), span)) if vertical else list(zip(span, fit(span)))
    return mask | polyline(pts, width)


# Objects hanging in the opening. They are room, not view, and no depth model
# gets them: flat cloth and a three-pixel rope against a far background.
#
# The rope used to be traced by hand. It turns out SAM does find it — from a
# BOX prompt, not a click. A click on a thin line gives it no sense of extent
# and it returns the wall behind instead (7-10% precision); a tight box states
# the extent and precision goes to 82%. Its answer also showed my traced path
# was a median 3px too high. Same trick for the cords things hang from.
in_opening = fill_line(sam('rope'), 7) | sam('laundry') | sam('bundle')
# One pixel of slack. An occluder that is a hair too generous costs nothing
# visible; one that is a hair too tight lets rain leak down its edge, which is
# exactly the artefact that makes the porthole look wrong.
in_opening = ndimage.binary_dilation(in_opening, np.ones((3, 3)))
lay[in_opening] = 4

# Hanging from the ceiling, in front of the back wall and behind the hammock.
for name in ('globe', 'plane_a', 'plane_b'):
    lay[sam(name)] = 3
for name in ('globe_cord', 'plane_a_cord', 'plane_b_cord'):
    lay[fill_line(sam(name), 4)] = 3

# The bedding heaped in the right end of the hammock — striped blanket, the
# packages on it, the teal cloth draping off the edge. Depth reads the blanket
# at 0.21, the same as the back wall thirty feet behind it, because the surface
# is blown out to near-white and offers no texture to key on. It rests in the
# hammock, so it takes the hammock's band. The polygon fills the gaps SAM's two
# masks leave between them, and is loose below and left where it can only
# overlap the sling, which is layer 4 already.
lay[sam('cargo') | sam('teal_drape')
    | poly((990, 700), (1100, 698), (1200, 678), (1265, 652), (1330, 618),
           (1410, 594), (1490, 592), (1545, 608), (1560, 660), (1570, 760),
           (1552, 880), (1528, 975), (1460, 998), (1360, 965), (1250, 880),
           (1120, 815), (1010, 780))] = 4

# The porthole rim is polished room structure, not part of the view. Depth puts
# slivers of it in the far band because it is dark and framed by the opening.
rim = ellipse(CX, CY, 240, 256) & ~ellipse(CX, CY, RX - 4, RY - 4)
lay[rim & (lay == 1)] = 2

# --- layer 0: exterior by attachment ---------------------------------------
arr = rgb.astype(np.float32) / 255.0
maxc, minc = arr.max(2), arr.min(2)
Lum = (maxc + minc) / 2
delta = maxc - minc
S = np.where(delta < 1e-6, 0.0, delta / (1.0 - np.abs(2 * Lum - 1) + 1e-6))
hue = np.zeros_like(Lum)
nz = delta > 1e-6
r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
rm, gm, bm = (maxc == r) & nz, (maxc == g) & nz, (maxc == b) & nz
hue[rm] = ((g - b)[rm] / delta[rm]) % 6
hue[gm] = ((b - r)[gm] / delta[gm]) + 2
hue[bm] = ((r - g)[bm] / delta[bm]) + 4
hue *= 60.0
far_like = (((hue >= 173) & (hue <= 288) & (S > 0.10))
            | ((S <= 0.20) & (Lum > 0.30))) & (Lum > 0.07)

room_like = ~far_like | in_opening
ap = ellipse(CX, CY, RX, RY)
room_like = ndimage.binary_closing(room_like, structure=np.ones((5, 5)))
lab, n = ndimage.label(room_like)
attached = np.unique(lab[room_like & ~ap])
room = np.isin(lab, attached[attached != 0]) | in_opening
exterior = ap & ~room
exterior = ndimage.binary_closing(ndimage.binary_opening(exterior, np.ones((3, 3))),
                                  np.ones((7, 7)))
lay[exterior] = 0

# Room material inside the opening is physically nearer than the view, so it
# must not keep a far-room band however dark the depth model made it.
lay[ap & room & (lay == 1)] = 4

L.save_layers(lay)
print(f'{n} room components, {len(attached)} attached to the room')

out = os.path.expanduser('~/Downloads/wallpaper-layers')
L.write_previews(lay, rgb, out)
Image.fromarray((d * 255).astype(np.uint8)).save(f'{out}/depth.png')
print('previews in', out)
