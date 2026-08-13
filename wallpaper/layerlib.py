#!/usr/bin/env python3
"""Shared definitions for the layer map.

layers.png is an index image: the value of a pixel IS its layer number, 0-5.
That makes it trivial to consume but nearly black to look at and impossible to
paint accurately by hand, which is what paint_export.py / paint_import.py are
for — they convert between the index image and a flat colour image with one
saturated colour per layer.

Layers are depth bands, not object categories. What matters when compositing is
the ordering: an effect placed at band k is drawn over bands <= k and occluded
by bands > k.
"""
import numpy as np
from PIL import Image
from scipy import ndimage

W, H = 1920, 1080

NAMES = {0: 'exterior', 1: 'far-room', 2: 'mid-room',
         3: 'near-mid', 4: 'near', 5: 'nearest'}

# Saturated and far apart in RGB, so that a soft brush edge or a JPEG-ish
# artefact still snaps back to the layer the painter meant.
PALETTE = {
    0: (0, 100, 255),      # blue    exterior, seen through the porthole
    1: (140, 90, 40),      # brown   far room: back walls, distant machinery
    2: (0, 200, 120),      # green   mid room
    3: (255, 210, 0),      # yellow  near-mid: bed plane, shelves
    4: (255, 60, 100),     # red     near: hammock, clothesline, laundry
    5: (160, 80, 255),     # purple  nearest: ceiling, overhead pipes, curtain
}


def load_layers(path='layers.png'):
    return np.asarray(Image.open(path)).astype(np.uint8)


def save_layers(lay, path='layers.png'):
    Image.fromarray(lay.astype(np.uint8)).save(path)


def to_colour(lay):
    out = np.zeros((*lay.shape, 3), np.uint8)
    for k, c in PALETTE.items():
        out[lay == k] = c
    return out


def snap(rgb):
    """Nearest palette entry per pixel. Antialiased edges resolve to whichever
    of the two layers they are closer to, which is the sane reading of a soft
    brush stroke."""
    # int32 throughout: a squared channel difference reaches 65025, which
    # overflows int16 and silently sends pixels to the wrong layer.
    keys = sorted(PALETTE)
    pal = np.array([PALETTE[k] for k in keys], np.int32)
    d = ((rgb[:, :, None, :].astype(np.int32) - pal[None, None]) ** 2).sum(-1)
    idx = d.argmin(-1)
    return np.array(keys, np.uint8)[idx]


def write_previews(lay, rgb, out):
    """One image per layer: that layer in full colour, everything else dimmed,
    with a yellow contour on the boundary. A misplaced edge is obvious."""
    import os
    os.makedirs(out, exist_ok=True)
    dim = (rgb.astype(np.float32) * 0.12).astype(np.uint8)
    for k, name in NAMES.items():
        sel = lay == k
        img = np.where(sel[..., None], rgb, dim)
        edge = ndimage.binary_dilation(sel, np.ones((3, 3))) & ~sel
        img[edge] = (255, 255, 0)
        Image.fromarray(img).save(f'{out}/layer{k}_{name}.png')
        print(f'  layer {k} {name:9s} {sel.sum() / lay.size * 100:5.1f}%')
    ov = to_colour(lay)
    Image.fromarray((rgb * 0.45 + ov * 0.55).astype(np.uint8)).save(f'{out}/overview.png')
