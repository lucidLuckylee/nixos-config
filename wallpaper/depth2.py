#!/usr/bin/env python3
"""Re-run depth estimation with a larger model, and at several scales.

The Small model put the whole ceiling in the far band. That is its known
weakness: overhead structure has no ground contact and no familiar scale, so a
small model reads the converging pipes as part of the back wall. Two changes:

  a bigger backbone   Large if it downloads, else Base. More capacity is worth
                      more here than any amount of band-edge tuning downstream.
  scale ensembling    the same image at three input resolutions, averaged after
                      per-scale normalisation. The coarse pass gets the global
                      near/far ordering right; the fine pass keeps the thin
                      structures — ropes, cables, the clothesline — that vanish
                      at low resolution. Averaging keeps both.

Usage: depth2.py [model-id] [-> depth.npy, depth_vis.png]
"""
import os
import sys
import numpy as np
import torch
from PIL import Image

os.environ.setdefault('HF_HOME', os.path.dirname(os.path.abspath(__file__)) + '/hf')

from transformers import AutoImageProcessor, AutoModelForDepthEstimation

CANDIDATES = ([sys.argv[1]] if len(sys.argv) > 1 else [
    'depth-anything/Depth-Anything-V2-Large-hf',
    'depth-anything/Depth-Anything-V2-Base-hf',
    'depth-anything/Depth-Anything-V2-Small-hf',
])
SCALES = [518, 924, 1288]

img = Image.open('v2.png').convert('RGB')
W, H = img.size

model = proc = used = None
for name in CANDIDATES:
    try:
        proc = AutoImageProcessor.from_pretrained(name)
        model = AutoModelForDepthEstimation.from_pretrained(name)
        used = name
        break
    except Exception as e:
        print(f'{name}: {type(e).__name__}: {e}', file=sys.stderr)
if model is None:
    sys.exit('no depth model could be loaded')
print('model:', used)

model.eval()
torch.set_num_threads(os.cpu_count() or 4)

acc = np.zeros((H, W), np.float32)
for s in SCALES:
    inputs = proc(images=img, return_tensors='pt', size={'height': s, 'width': s})
    with torch.no_grad():
        pred = model(**inputs).predicted_depth
    if pred.ndim == 3:
        pred = pred.unsqueeze(1)
    up = torch.nn.functional.interpolate(pred, size=(H, W), mode='bicubic',
                                         align_corners=False)[0, 0].numpy()
    # Normalise per scale before averaging: the raw outputs are in arbitrary
    # units that differ between input sizes, so summing them unnormalised would
    # just weight by whichever pass happened to have the largest range.
    up = (up - up.min()) / (up.max() - up.min() + 1e-9)
    acc += up
    print(f'  scale {s}: done')

d = acc / len(SCALES)
d = (d - d.min()) / (d.max() - d.min() + 1e-9)
np.save('depth.npy', d)
Image.fromarray((d * 255).astype(np.uint8)).save('depth_vis.png')

qs = [0, 5, 10, 25, 50, 75, 90, 95, 100]
print('depth percentiles:', {q: round(float(np.percentile(d, q)), 3) for q in qs})
