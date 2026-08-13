#!/usr/bin/env python3
"""Assets for the weather cycle: sprinkle, heavy rain, fog, lightning, LEDs.

The rain plates follow assets4.sh's rules — generate at a resolution, scale to a
common 512x1200, so streak WIDTH varies as well as length and density. Streaks
are drawn at 12 degrees off vertical to match the -0.2133 scroll ratio, the only
one where all layers wrap seamlessly in x over a 512px tile.

Fog and the flash are periodic by construction so they can be scrolled or
pulsed without a seam.
"""
import numpy as np
from PIL import Image
from scipy import ndimage

RNG = np.random.default_rng(31415)
TILT = 0.2133          # dx/dy, matching the scroll


def streaks(gen_w, gen_h, density, length, tint, alpha, soften=0.0):
    """Seeded points smeared along the fall direction, then scaled to 512x1200."""
    g = np.zeros((gen_h, gen_w), np.float32)
    n = int(density * gen_w * gen_h)
    ys = RNG.integers(0, gen_h, n)
    xs = RNG.integers(0, gen_w, n)
    g[ys, xs] = RNG.uniform(0.45, 1.0, n)
    # Smear along the streak direction: down and to the left.
    out = np.zeros_like(g)
    for k in range(length):
        w = 1.0 - k / length
        dy, dx = k, -int(round(k * TILT))
        out += w * np.roll(np.roll(g, dy, 0), dx, 1)
    out /= max(out.max(), 1e-6)
    im = Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).resize(
        (512, 1200), Image.LANCZOS)
    a = np.asarray(im).astype(np.float32) / 255.0
    if soften:
        a = ndimage.gaussian_filter(a, soften)
    a = np.clip(a * alpha, 0, 1)
    rgb = np.zeros((1200, 512, 3), np.uint8)
    rgb[:] = tint
    Image.fromarray(np.dstack([rgb, (a * 255).astype(np.uint8)]), 'RGBA')\
        .save(f'{streaks.name}.png')
    print(f'{streaks.name}.png  gen {gen_w}x{gen_h}  {n} seeds  len {length}')


# Sprinkle: few, short, fine, faint — and generated large so scaling down makes
# the streaks sub-pixel thin, which is what "light" looks like.
streaks.name = 'rain_sprinkle'
streaks(1100, 2600, 0.00022, 26, (176, 198, 224), 0.34, soften=0.6)

# Heavy: dense, long, fat, bright. Generated small so scaling UP fattens it.
streaks.name = 'rain_heavy'
streaks(300, 700, 0.00075, 30, (232, 244, 255), 0.85)

# --- fog --------------------------------------------------------------------
# Periodic noise (gaussian_filter with wrap) so it can scroll without a seam.
n = RNG.random((600, 512)).astype(np.float32)
n = ndimage.gaussian_filter(n, (34, 52), mode='wrap')
n -= n.min()
n /= n.max()
n = n ** 1.5
fog = np.zeros((600, 512, 3), np.uint8)
fog[:] = (196, 212, 228)
Image.fromarray(np.dstack([fog, (n * 0.5 * 255).astype(np.uint8)]), 'RGBA')\
    .save('fog.png')
print('fog.png 512x600, peak alpha', round(float(n.max() * 0.5), 3))

# --- lightning --------------------------------------------------------------
# A soft wash over the whole opening: this is a flash somewhere out there, not a
# bolt in the window. Masked to the porthole at composite time.
yy, xx = np.mgrid[0:1080, 0:1920].astype(np.float32)
d = np.exp(-(((xx - 470) / 340) ** 2 + ((yy - 470) / 300) ** 2))
flash = np.zeros((1080, 1920, 3), np.uint8)
flash[:] = (222, 234, 255)
Image.fromarray(np.dstack([flash, (d * 255 * 0.85).astype(np.uint8)]), 'RGBA')\
    .save('flash.png')
print('flash.png 1920x1080')

# --- washing machine indicator ---------------------------------------------
# Three states: running, cleaning, finished.
R = 17
yy, xx = np.mgrid[-R:R + 1, -R:R + 1].astype(np.float32)
dd = np.hypot(xx, yy)
core = np.exp(-(dd / 2.2) ** 2)
halo = np.exp(-(dd / (R * 0.42)) ** 2) * 0.75
a = np.clip(core + halo, 0, 1)
for name, c in (('cyan', (110, 240, 235)), ('red', (255, 88, 66)),
                ('green', (120, 255, 140))):
    px = np.clip(np.array(c, np.float32) * (0.60 + 0.40 * core[..., None])
                 + 200 * core[..., None], 0, 255)
    Image.fromarray(np.dstack([px, a * 255]).astype(np.uint8), 'RGBA')\
        .save(f'led_{name}.png')
print('led_cyan.png, led_red.png, led_green.png', f'{2 * R + 1}x{2 * R + 1}')
