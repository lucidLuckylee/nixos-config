#!/usr/bin/env python3
"""An exact boundary for the porthole opening, instead of an inset ellipse.

The rain matte has been `(layer 0) AND (ellipse inset by 15px)`. The inset was
a workaround: the rim is polished metal whose reflections read as sky, so rain
fell on the border itself, and pulling the ellipse inwards hid the problem
geometrically. It costs a ring of real view all the way round, and where the
true opening is not exactly elliptical the rain still ends in the wrong place.

SAM can give the actual boundary. Several prompt sets are tried, because for a
large region SAM's three candidates are usually {opening, opening+rim, whole
assembly} and its own confidence does not reliably pick the first. Each is
scored against the nominal ellipse: a candidate that IS the opening overlaps it
well, one that swallowed the rim is much larger, one that fragmented is much
smaller. The best-scoring mask wins, and the runner-up is saved to compare.

Writes sam/port_glass.png plus overlays.
"""
import os
import numpy as np
import torch
from PIL import Image, ImageDraw

os.environ.setdefault('HF_HOME', os.path.dirname(os.path.abspath(__file__)) + '/hf')
from transformers import SamModel, SamProcessor

W, H = 1920, 1080
CX, CY, RX, RY = 466, 543, 194, 221

img = Image.open('v2.png').convert('RGB')
ell = Image.new('L', (W, H), 0)
ImageDraw.Draw(ell).ellipse([CX - RX, CY - RY, CX + RX, CY + RY], fill=255)
ell = np.asarray(ell) > 0

model = SamModel.from_pretrained('facebook/sam-vit-huge').eval()
proc = SamProcessor.from_pretrained('facebook/sam-vit-huge')
torch.set_num_threads(os.cpu_count() or 4)
enc = proc(img, return_tensors='pt')
with torch.no_grad():
    emb = model.get_image_embeddings(enc['pixel_values'])

BOX = [262, 300, 712, 790]
# Points chosen inside the visible parts of the view, avoiding the hammock
# strap and the laundry, which cross the opening and are not part of it.
VIEW = [(320, 420), (560, 400), (620, 560), (330, 620), (500, 700), (600, 660)]
RIM = [(485, 312), (272, 540), (702, 540), (485, 772)]

TRIALS = {
    'box':            dict(input_boxes=[[BOX]]),
    'box+view':       dict(input_boxes=[[BOX]],
                           input_points=[[VIEW]], input_labels=[[[1] * len(VIEW)]]),
    'box+view-rim':   dict(input_boxes=[[BOX]],
                           input_points=[[VIEW + RIM]],
                           input_labels=[[[1] * len(VIEW) + [0] * len(RIM)]]),
    'view-rim':       dict(input_points=[[VIEW + RIM]],
                           input_labels=[[[1] * len(VIEW) + [0] * len(RIM)]]),
}

os.makedirs('sam', exist_ok=True)
arr = np.asarray(img)
results = []
print(f'{"prompt":14s} {"cand":4s} {"iou":>6s} {"px":>8s} {"IoU-ellipse":>12s} {"area/ell":>9s}')
for name, kw in TRIALS.items():
    inp = proc(img, return_tensors='pt', **kw)
    inp.pop('pixel_values')
    with torch.no_grad():
        out = model(image_embeddings=emb, multimask_output=True, **inp)
    masks = proc.image_processor.post_process_masks(
        out.pred_masks.cpu(), inp['original_sizes'].cpu(),
        inp['reshaped_input_sizes'].cpu())[0][0].numpy()
    scores = out.iou_scores[0, 0].detach().numpy()
    for i, m in enumerate(masks):
        iou = (m & ell).sum() / max((m | ell).sum(), 1)
        print(f'{name:14s} {i:<4d} {scores[i]:6.3f} {int(m.sum()):8d} '
              f'{iou:11.3f} {m.sum() / ell.sum():8.2f}')
        results.append((iou, name, i, m))

results.sort(key=lambda r: -r[0])
for rank, (iou, name, i, m) in enumerate(results[:2]):
    tag = 'port_glass' if rank == 0 else 'port_glass_runnerup'
    Image.fromarray((m * 255).astype(np.uint8)).save(f'sam/{tag}.png')
    ov = arr.copy()
    ov[m] = (ov[m] * 0.45 + np.array([255, 40, 90]) * 0.55).astype(np.uint8)
    Image.fromarray(ov[280:800, 240:740]).save(f'sam/ov_{tag}.png')
    print(f'{tag}: {name} candidate {i}, IoU with ellipse {iou:.3f}')
