#!/usr/bin/env python3
"""Steam plume: turbulent particles instead of eight blurred circles.

steam2.sh drew 8 circles, grew them, and blurred the result. At a glance that
is a plume; looked at directly it is eight balls, because a circle has no
internal structure and blurring only removes what little it had.

What makes vapour read as vapour is that it is lumpy at several scales at once
and it shears as it rises. So: ~150 particles, each rendered as a radial
falloff modulated by its own angular harmonics — a torn, irregular wisp rather
than a disc — advected through a shear field that stretches and tilts them as
they climb.

Everything here is periodic over LOOP seconds, which is what lets the render
`-stream_loop` the sequence with no seam:

  particle age   lifetimes divide LOOP, and emission phases are spread evenly
                 across a lifetime, so the population is in steady state
  wander         sums of sinusoids at INTEGER multiples of 1/LOOP
  no simulation  nothing integrates state frame to frame, so there is no
                 transient to settle and frame 0 equals frame LOOP*FPS

Rendered on BLACK, not transparent: the plume is screen-blended into the frame,
and screen treats black as identity. Alpha-compositing it laid a grey film over
the plate, which is what made the very first version read as lens glow.
"""
import numpy as np
from PIL import Image
import os

W, H = 220, 340          # 2x the composite size; ffmpeg scales down, which
FPS, LOOP = 60, 6.0      # antialiases the wisp edges for free
N = 150
LIFE = 3.0               # divides LOOP
RNG = np.random.default_rng(4242)

EMIT_X, EMIT_Y = W * 0.52, H - 14
RISE = H * 0.80
SPREAD = W * 0.17

phase = RNG.uniform(0, LIFE, N)
seed_a = RNG.uniform(0, 2 * np.pi, (N, 3))     # angular harmonic phases
seed_w = RNG.uniform(0, 2 * np.pi, (N, 2))     # wander phases
lean = RNG.normal(0, 1, N)
sizef = RNG.uniform(0.75, 1.5, N)
brite = RNG.uniform(0.55, 1.0, N)
xoff = RNG.normal(0, W * 0.055, N)

yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
frames = int(LOOP * FPS)
os.makedirs('steam', exist_ok=True)

for f in range(frames):
    t = f / FPS
    acc = np.zeros((H, W), np.float32)
    for p in range(N):
        u = ((t + phase[p]) % LIFE) / LIFE          # age, 0..1
        # Rise decelerates as the puff loses buoyancy and entrains air.
        y = EMIT_Y - RISE * (u ** 0.82)
        # Wander at exactly 1 and 2 cycles per loop, so it is loop-periodic.
        w = (np.sin(2 * np.pi * t / LOOP + seed_w[p, 0])
             + 0.5 * np.sin(4 * np.pi * t / LOOP + seed_w[p, 1]))
        x = EMIT_X + xoff[p] + SPREAD * u * (0.35 * lean[p] + 0.55 * w)
        r = (3.5 + 21.0 * u ** 0.72) * sizef[p]

        # Shear: higher puffs are stretched horizontally and tilted, which is
        # what stops a column of blobs looking like a column of blobs.
        sx = 1.0 + 0.55 * u
        sy = 1.0 - 0.30 * u
        tilt = 0.45 * u * (lean[p] + w)

        rad = 2.0 * r * max(sx, sy) * (1.0 + abs(tilt))
        x0, x1 = max(0, int(x - rad)), min(W, int(x + rad) + 1)
        y0, y1 = max(0, int(y - rad)), min(H, int(y + rad) + 1)
        if x1 <= x0 or y1 <= y0:
            continue
        lyy, lxx = yy[y0:y1, x0:x1], xx[y0:y1, x0:x1]
        dx = (lxx - x) / (r * sx)
        dy = (lyy - y) / (r * sy)
        dxr = dx + tilt * dy
        d = np.sqrt(dxr * dxr + dy * dy) + 1e-6
        ang = np.arctan2(dy, dxr)
        # Angular harmonics tear the outline; deeper as the puff ages and the
        # eddies that shred it have had time to work.
        lump = (1.0
                + 0.30 * (0.4 + 0.6 * u) * np.sin(3 * ang + seed_a[p, 0])
                + 0.20 * (0.4 + 0.6 * u) * np.sin(5 * ang + seed_a[p, 1])
                + 0.12 * (0.4 + 0.6 * u) * np.sin(8 * ang + seed_a[p, 2]))
        core = np.exp(-2.2 * (d / np.clip(lump, 0.35, None)) ** 2)

        # Born faint, brightest early, gone by the end; thinner as it spreads.
        env = (np.sin(np.pi * np.clip(u, 0, 1)) ** 1.2) * (1.0 - u) ** 0.8
        acc[y0:y1, x0:x1] += core * env * brite[p] * (0.85 - 0.45 * u)

    v = np.clip(acc * 0.135, 0, 1) ** 0.92
    rgb = (v[..., None] * np.array([236, 243, 252])).astype(np.uint8)
    Image.fromarray(rgb).save(f'steam/steam_{f:03d}.png')

print(f'{frames} frames, {W}x{H}, {N} particles, loop {LOOP}s')
