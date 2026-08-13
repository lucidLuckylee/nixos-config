#!/usr/bin/env python3
"""Segment named objects with SAM, so layer edges follow the artwork.

Depth answers "how far", not "where does this object end". The two failures
left in the layer map are both boundary problems, not distance problems: the
laundry hanging in the porthole and the cloth bundle on the line were traced by
hand as rectangles, and rectangles they look like.

SAM takes a click and returns the object under it. One point per object, and
the edges come from the image instead of from me reading coordinates off a
zoomed screenshot.

The image embedding is computed once and reused for every prompt, which is why
this is worth doing for many objects at once rather than one at a time.

Writes sam/<name>.png (binary mask) and sam/overlay_<name>.jpg (to check it).
"""
import os
import sys
import numpy as np
import torch
from PIL import Image

os.environ.setdefault('HF_HOME', os.path.dirname(os.path.abspath(__file__)) + '/hf')

from transformers import SamModel, SamProcessor

MODEL = sys.argv[1] if len(sys.argv) > 1 else 'facebook/sam-vit-huge'

# name: (points that are inside the object, points that are NOT, optional box)
#
# The rope needs the box. A click on a three-pixel line gives SAM no sense of
# how far the thing extends, and it returns the wall behind it instead — the
# point prompts scored 7-10% precision against the rope. A tight box states the
# extent, and precision jumps to 82%. Worth remembering for any thin structure.
PROMPTS = {
    'rope':         ([], [], (285, 436, 700, 492)),
    # The cords things hang from. Same box trick as the rope, same reason.
    'globe_cord':   ([], [], (620, 0, 730, 178)),
    'plane_a_cord': ([], [], (903, 8, 947, 162)),
    'plane_b_cord': ([], [], (1098, 12, 1147, 212)),
    'laundry':      ([(390, 570), (400, 640)], [(330, 560), (470, 600)], None),
    'bundle':       ([(617, 470)], [(560, 450), (670, 470)], None),
    'globe':        ([(688, 245)], [], None),
    'plane_a':      ([(900, 172)], [], None),
    'plane_b':      ([(1065, 235)], [], None),
    'hammock':      ([(900, 800), (600, 700)], [], None),
    'cargo':        ([(1300, 640), (1200, 700)], [(1300, 900)], None),
    'teal_drape':   ([(1450, 850)], [], None),
    'washer':       ([(1700, 880)], [], None),
    'drape_top_r':  ([(1550, 150)], [], None),
}

# Prompts whose object is the SMALLEST of SAM's three candidates, not the
# highest-scored one. See the comment at the pick below.
SMALLEST = {'rope', 'globe_cord', 'plane_a_cord', 'plane_b_cord'}

img = Image.open('v2.png').convert('RGB')
W, H = img.size

print('loading', MODEL)
model = SamModel.from_pretrained(MODEL).eval()
proc = SamProcessor.from_pretrained(MODEL)
torch.set_num_threads(os.cpu_count() or 4)

# One forward pass of the image encoder, reused for every prompt below.
enc = proc(img, return_tensors='pt')
with torch.no_grad():
    emb = model.get_image_embeddings(enc['pixel_values'])
print('image embedded')

os.makedirs('sam', exist_ok=True)
arr = np.asarray(img)

for name, (pos, neg, box) in PROMPTS.items():
    kw = {}
    if pos or neg:
        kw['input_points'] = [[[list(p) for p in pos + neg]]]
        kw['input_labels'] = [[[1] * len(pos) + [0] * len(neg)]]
    if box:
        kw['input_boxes'] = [[list(box)]]
    inp = proc(img, return_tensors='pt', **kw)
    inp.pop('pixel_values')
    with torch.no_grad():
        out = model(image_embeddings=emb, multimask_output=True, **inp)
    masks = proc.image_processor.post_process_masks(
        out.pred_masks.cpu(), inp['original_sizes'].cpu(),
        inp['reshaped_input_sizes'].cpu())[0][0].numpy()
    scores = out.iou_scores[0, 0].detach().numpy()

    # SAM returns three nested candidates (part / subpart / whole). Usually the
    # highest-scored one is right, but not for the rope: there its own scores
    # rank the mask that swallows the wall behind the line ABOVE the mask that
    # is the line (0.594 vs 0.508), while precision against the rope runs the
    # other way (31% vs 82%). For a thin structure the smallest candidate is
    # the object and the larger ones are what it lies on, so pick by size.
    best = (int(np.argmin([m.sum() for m in masks])) if name in SMALLEST
            else int(scores.argmax()))
    for i, m in enumerate(masks):
        tag = name if i == best else f'{name}_alt{i}'
        Image.fromarray((m * 255).astype(np.uint8)).save(f'sam/{tag}.png')
    m = masks[best]
    ys, xs = np.where(m)
    ov = arr.copy()
    ov[m] = (ov[m] * 0.45 + np.array([255, 40, 90]) * 0.55).astype(np.uint8)
    Image.fromarray(ov).save(f'sam/overlay_{name}.jpg', quality=88)
    bbox = (xs.min(), ys.min(), xs.max(), ys.max()) if len(xs) else None
    print(f'{name:12s} iou {scores[best]:.3f}  {m.sum():7d}px  bbox {bbox}')

print('masks in sam/')
