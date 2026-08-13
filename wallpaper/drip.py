#!/usr/bin/env python3
"""The drip: a wet patch on the pipe, drops forming, falling, landing.

The whole thing is baked into one RGBA sequence rather than driven by overlay
expressions, because the interesting parts — the drop filling, sagging and
necking until surface tension loses, then the puddle rippling — are shape
changes over time, and `overlay` can only translate a fixed sprite.

The sequence is the FULL 48s loop, not half of it. Half a loop meant every drip
was identical to the last; over the whole loop there is room for three, forming
at different places on the wet patch, which is what stops it looking like a
mechanism resetting.

Per drop, from its own start time:

     0 - 7    it swells among the beads, drawing water from its neighbours
     7 - 9.4  it lets go and falls ~610px, accelerating
    ~7.9-9.0  it passes behind the hammock and is briefly gone
     9.4-12.4 it hits the puddle: a crown, then two rings

Always: the pipe carries a patch of condensation, and a puddle sits on the
floorboards below.

Occlusion is not handled here. drip_front.png redraws layer >= 4 (the hammock)
on top of this sequence, so a drop disappears behind it and re-emerges below.
Layers 2-3 must NOT occlude: the floor and its edge are behind the drop.

See README for the three things that make water read as water — dark body,
bright lower rim, and condensation that is mostly catchlight.
"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage

W, H = 140, 720           # region pasted at (928, 340) in the frame
FPS, LOOP = 30, 48.0
REGION = (928, 340)
RNG = np.random.default_rng(90210)

# The pipe's lower edge, MEASURED off the plate (per-column max luminance
# gradient, robust-fitted). An earlier guess had this sloping the wrong way,
# so the beads tracked a line that does not exist and slid off the metal.
def edge_y(xl):
    return 55.6 - 0.171 * xl


# The wet patch: deliberately small. Spread over the whole pipe it read as
# grain; concentrated it reads as one spot that sweats.
#
# Its edge is feathered rather than cut. A patch of uniform bead density inside
# a box and nothing outside it reads as a rectangle of sparkle sitting on the
# pipe; damp metal shades off gradually into dry. `wetness()` drives BOTH the
# density (by rejection sampling) and the brightness, because fading only the
# brightness still leaves the same number of beads out at the rim, and fading
# only the density leaves the outermost ones at full strength.
WET_X0, WET_X1 = 38.0, 108.0
WET_RISE = 24.0
WET_CX = 0.5 * (WET_X0 + WET_X1)
WET_HX = 0.5 * (WET_X1 - WET_X0)


def wetness(xl, dv):
    """0..1 across the patch. `dv` is height above the pipe's lower edge."""
    u = np.clip(np.abs(xl - WET_CX) / WET_HX, 0, 1)
    fx = 0.5 * (1.0 + np.cos(np.pi * u))                  # raised cosine
    fv = np.clip(1.0 - (np.clip(dv, 0, None) / WET_RISE) ** 1.4, 0, 1)
    return fx * fv

# (start time, x on the pipe) — three drops, three places.
DROPS = [(1.0, 56.0), (17.0, 88.0), (32.0, 70.0)]
T_FORM, T_FALL, T_RIPPLE = 7.0, 2.4, 3.0

PUDDLE = np.array([70.0, 662.0])   # floorboards under the hammock (frame y=1002)
PUD_RX, PUD_RY = 34.0, 8.5

# Rejection-sample against `wetness`, so beads thin out towards the rim instead
# of stopping at a line. Oversample and keep what survives.
_cx = RNG.uniform(WET_X0, WET_X1, 4000)
_cdv = RNG.uniform(0, 1, 4000) ** 1.7 * WET_RISE
_keep = RNG.uniform(0, 1, 4000) < wetness(_cx, _cdv)
_cx, _cdv = _cx[_keep][:300], _cdv[_keep][:300]
NBEAD = len(_cx)
bead_x = _cx
bead_y = edge_y(bead_x) - _cdv
# Amplitude falloff on top of the density falloff, so the last few beads at the
# rim are faint rather than full strength.
bead_w = wetness(bead_x, _cdv) ** 0.55
bead_r = 0.40 + RNG.uniform(0, 1, NBEAD) ** 2.5 * 1.5
# Power-law glints: most beads barely catch the light, a few catch it hard.
bead_glint = 0.05 + RNG.uniform(0, 1, NBEAD) ** 3.0 * 0.70
bead_k = RNG.integers(1, 4, NBEAD)
bead_ph = RNG.uniform(0, 2 * np.pi, NBEAD)
bead_wob = RNG.uniform(0.15, 0.7, NBEAD)

NCROWN = 8
cr_ang = RNG.uniform(0.22, np.pi - 0.22, NCROWN)
cr_spd = RNG.uniform(0.6, 1.0, NCROWN)

yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)

# --- the puddle -------------------------------------------------------------
# Not an ellipse. A perfect one reads as a drawn shape, so the radius is
# modulated by a few angular harmonics: still a puddle, but one that spilled.
_pdx = (xx - PUDDLE[0]) / PUD_RX
_pdy = (yy - PUDDLE[1]) / PUD_RY
_ang = np.arctan2(_pdy, _pdx)
_shape = (1.0 + 0.16 * np.sin(3 * _ang + 0.7)
          + 0.10 * np.sin(5 * _ang + 2.1)
          - 0.07 * np.sin(2 * _ang + 4.3))
pd_r = np.sqrt(_pdx ** 2 + _pdy ** 2) / _shape
pud_mask = np.clip((1.0 - pd_r) / 0.18, 0, 1)
pud_edge = np.exp(-((pd_r - 0.93) ** 2) / 0.005) * 0.14

# Standing water is a mirror, not a grey disc: it samples the room above it,
# mirrored about its own centre line and compressed, because the surface is
# seen at a very shallow angle.
COMPRESS = 0.28
plate = np.asarray(Image.open('v2.png').convert('RGB'), np.float32)
PH, PW = plate.shape[:2]

_bx0, _bx1 = int(PUDDLE[0] - PUD_RX * 1.3), int(PUDDLE[0] + PUD_RX * 1.3 + 1)
_by0, _by1 = int(PUDDLE[1] - PUD_RY * 1.4), int(PUDDLE[1] + PUD_RY * 1.4 + 1)
_ly, _lx = np.mgrid[_by0:_by1, _bx0:_bx1].astype(np.float32)
_src_y0 = (REGION[1] + PUDDLE[1]) - (_ly - PUDDLE[1]) / COMPRESS
_src_x0 = REGION[0] + _lx
_pud_mask_b = pud_mask[_by0:_by1, _bx0:_bx1]


def reflection(dy):
    """Sample the room above the puddle. `dy` is a per-pixel vertical offset in
    plate rows — which is what a ripple does to a reflection, and far more
    convincing than drawing rings on top of it."""
    sy = np.clip(_src_y0 + dy, 0, PH - 1)
    sx = np.clip(_src_x0, 0, PW - 1)
    out = np.empty((*sy.shape, 3), np.float32)
    for c in range(3):
        out[..., c] = ndimage.map_coordinates(plate[..., c], [sy, sx], order=1,
                                              mode='nearest')
    return out


def smooth(a, b, t):
    u = np.clip((t - a) / (b - a), 0, 1)
    return u * u * (3 - 2 * u)


def add(acc, cx, cy, rx, ry, amp, soft=1.0):
    """A soft elliptical blob, bounded to its own box."""
    rad = 3.0 * max(rx, ry) * soft
    x0, x1 = max(0, int(cx - rad)), min(W, int(cx + rad) + 1)
    y0, y1 = max(0, int(cy - rad)), min(H, int(cy + rad) + 1)
    if x1 <= x0 or y1 <= y0 or amp <= 0:
        return
    dx = (xx[y0:y1, x0:x1] - cx) / max(rx, 1e-3)
    dy = (yy[y0:y1, x0:x1] - cy) / max(ry, 1e-3)
    acc[y0:y1, x0:x1] += amp * np.exp(-(dx * dx + dy * dy) / (soft * soft))


def teardrop(acc, cx, cy, r, stretch, neck, rim=None):
    """Round at the bottom, tapering to a point at the top; `neck` pinches the
    taper as surface tension gives out.

    `acc` gets the BODY, which is DARK — a drop refracts what is behind it, and
    behind this one is unlit machinery. `rim` gets the bright edge, weighted to
    the bottom where the light gathers. Rendering the body bright instead made
    this look like a glowing pill.
    """
    ry = r * stretch
    rad = 3.2 * max(r, ry)
    x0, x1 = max(0, int(cx - rad)), min(W, int(cx + rad) + 1)
    y0, y1 = max(0, int(cy - rad)), min(H, int(cy + rad) + 1)
    if x1 <= x0 or y1 <= y0:
        return
    lx, ly = xx[y0:y1, x0:x1], yy[y0:y1, x0:x1]
    v = (ly - cy) / max(ry, 1e-3)
    wid = np.clip(1.0 - (np.clip(-v, 0, 2) ** (1.0 + 2.2 * neck)), 0, 1)
    d = ((lx - cx) / np.maximum(r * wid, 1e-3)) ** 2 + np.clip(v, 0, 3) ** 2
    # Multiplying by the width profile closes the taper. Without it, as `wid`
    # goes to zero the divisor does too, but on the centre line the numerator
    # is also zero — so d = 0 and the pixel comes out fully opaque, leaving a
    # one-pixel column of maximum alpha running up out of the drop.
    acc[y0:y1, x0:x1] += np.exp(-2.4 * d) * wid ** 0.7
    if rim is not None:
        dd = np.sqrt(d)
        lower = np.clip(v + 0.35, 0, 1.4) / 1.4
        rim[y0:y1, x0:x1] += (np.exp(-((dd - 0.90) ** 2) / 0.028)
                              * wid ** 0.8 * (0.06 + 0.52 * lower))


os.makedirs('drip', exist_ok=True)
frames = int(LOOP * FPS)
for f in range(frames):
    t = f / FPS
    wat = np.zeros((H, W), np.float32)      # drop body (dark)
    wrim = np.zeros((H, W), np.float32)     # drop rim (bright)
    hil = pud_edge.copy()                   # catchlights
    bdrk = np.zeros((H, W), np.float32)     # beads: dark lens
    bhil = np.zeros((H, W), np.float32)     # beads: warm catchlights
    vap = np.zeros((H, W), np.float32)
    ripple_dy = np.zeros_like(_pud_mask_b)

    # --- the wet patch, always -------------------------------------------
    # `feed`: the bead that is winning takes water from its neighbours and they
    # recover afterwards. Each drop has its own, centred on where it forms.
    feed = []
    for t0, sx in DROPS:
        u = (t - t0) / T_FORM
        if -0.1 < u < 1.6:
            feed.append((sx, smooth(t0, t0 + T_FORM, t)
                         * (1.0 - smooth(t0 + T_FORM, t0 + T_FORM + 3.0, t))))
    for i in range(NBEAD):
        ph = 2 * np.pi * bead_k[i] * t / LOOP + bead_ph[i]
        w = np.sin(ph)
        r = bead_r[i] * (1.0 + 0.13 * w)
        bx = bead_x[i] + bead_wob[i] * 0.7 * w
        by = bead_y[i] + bead_wob[i] * 0.4 * np.cos(ph)
        a = 1.0
        for sx, fv in feed:
            near = np.exp(-(((bx - sx) / 13.0) ** 2
                            + ((by - edge_y(sx)) / 10.0) ** 2))
            a *= 1.0 - 0.72 * fv * near
            r *= 1.0 - 0.45 * fv * near
        # A bead is a dark lens with a catchlight. On dark metal the catchlight
        # is nearly all you see, so the darkening stays well under the drop's.
        add(bdrk, bx, by + r * 0.18, r * 1.25, r * 1.1, 0.17 * a * bead_w[i])
        add(bhil, bx - r * 0.34, by - r * 0.30,
            max(0.42, r * 0.26), max(0.42, r * 0.26),
            bead_glint[i] * a * bead_w[i])

    # --- each drop --------------------------------------------------------
    for t0, sx in DROPS:
        sy = edge_y(sx)
        # forming
        if t0 < t < t0 + T_FORM:
            g = smooth(t0, t0 + T_FORM, t)
            r = 0.6 + 2.2 * g
            neck = smooth(0.55, 1.0, g)
            cy = sy + 3 + 5.5 * g + 2.5 * neck
            teardrop(wat, sx, cy, r, 1.15 + 0.55 * neck, neck, wrim)
            add(hil, sx - r * 0.40, cy - r * 0.34, max(0.7, r * 0.22),
                max(0.7, r * 0.22), 0.95 * g, 1.0)
        # falling
        tf = t - (t0 + T_FORM)
        if 0 <= tf < T_FALL:
            u = tf / T_FALL
            y0d = sy + 12
            y = y0d + (PUDDLE[1] - y0d) * (0.34 * u + 0.66 * u * u)
            speed = 0.34 + 1.32 * u
            teardrop(wat, sx, y, 2.7, 1.10 + 0.45 * speed, 0.42, wrim)
            add(hil, sx - 1.3, y - 1.8, 1.05, 1.5, 1.0, 1.0)
            add(vap, sx, y - 6 * speed, 1.8, 5.0, 0.030, 1.2)
        # landing: ripples spread from where it actually hit, not from the
        # puddle's centre, so a drop landing off to one side looks like it.
        tr = t - (t0 + T_FORM + T_FALL)
        if 0 <= tr < T_RIPPLE:
            u = tr / T_RIPPLE
            if u < 0.18:
                k = u / 0.18
                for i in range(NCROWN):
                    rr = 2.5 + 13.0 * k * cr_spd[i]
                    add(hil, sx + np.cos(cr_ang[i]) * rr,
                        PUDDLE[1] - np.sin(cr_ang[i]) * rr * 0.60 + 7.0 * k * k,
                        1.0, 1.4, 0.8 * (1 - k))
                add(hil, sx, PUDDLE[1] - 2, 2.6, 1.4, 0.75 * (1 - k))
            # Two rings, not three: the puddle is shallow and a small drop does
            # not set up a whole wave train.
            hit_r = np.sqrt(((_lx - sx) / PUD_RX) ** 2
                            + ((_ly - PUDDLE[1]) / PUD_RY) ** 2)
            for delay in (0.0, 0.30):
                ru = (u - delay) / (1.0 - delay)
                if ru <= 0:
                    continue
                rad = 0.10 + 0.95 * ru
                amp = 19.0 * (1 - ru) ** 1.8
                sgn = (hit_r - rad) / 0.085
                ripple_dy += -sgn * np.exp(-sgn * sgn) * amp * _pud_mask_b
                hil[_by0:_by1, _bx0:_bx1] += (np.exp(-sgn * sgn) * 0.085
                                              * (1 - ru) ** 1.8 * _pud_mask_b)

    # --- composite --------------------------------------------------------
    body = np.clip(wat, 0, 1)
    hil = np.clip(hil, 0, 1)
    wrim = np.clip(wrim, 0, 1)
    bdrk = np.clip(bdrk, 0, 1)
    bhil = np.clip(bhil, 0, 1)
    w = vap * 0.85 + body * 0.90 + wrim + hil + bdrk + bhil
    alpha = np.clip(w, 0, 1)
    col = (vap[..., None] * np.array([186, 202, 218])
           + body[..., None] * np.array([24, 30, 40])        # dark: it refracts
           + wrim[..., None] * np.array([206, 224, 242])     # bright outline
           + hil[..., None] * np.array([248, 252, 255])      # catchlight
           + bdrk[..., None] * np.array([28, 26, 24])
           + bhil[..., None] * np.array([252, 238, 214]))    # warm: lit by lamps
    col = np.clip(col / np.clip(w, 1e-3, None)[..., None], 0, 255)

    # The reflection goes UNDER what is already drawn here, so the crown and the
    # ripple sheen sit on the water rather than being replaced by it.
    refl = reflection(ripple_dy) * 0.58
    pa = _pud_mask_b * 0.55                 # shallower than before: less full
    top_a = alpha[_by0:_by1, _bx0:_bx1]
    top_c = col[_by0:_by1, _bx0:_bx1]
    out_a = top_a + pa * (1 - top_a)
    out_c = ((top_c * top_a[..., None] + refl * pa[..., None] * (1 - top_a)[..., None])
             / np.clip(out_a, 1e-3, None)[..., None])
    alpha[_by0:_by1, _bx0:_bx1] = out_a
    col[_by0:_by1, _bx0:_bx1] = np.clip(out_c, 0, 255)

    Image.fromarray(np.dstack([col, alpha * 255]).astype(np.uint8), 'RGBA').save(
        f'drip/drip_{f:04d}.png')

print(f'{frames} frames, {W}x{H}, {FPS}fps, loop {LOOP}s')
print(f'{len(DROPS)} drops at x={[d[1] for d in DROPS]}, '
      f'wet patch x {WET_X0:.0f}-{WET_X1:.0f} ({NBEAD} beads), '
      f'puddle {PUD_RX:.0f}x{PUD_RY:.0f}')
