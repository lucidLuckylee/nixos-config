#!/usr/bin/env python3
"""Can SAM segment the clothesline? Test it rather than assume.

I claimed it could not and traced the rope by hand. That claim was never tested.
Three prompt styles, all three SAM candidates kept for each, so the answer is
based on what comes back and not on what I expected:

  one point     a single click on the rope
  many points   points spread along its whole span
  box           a tight box around the span, which is the prompt style that
                usually rescues thin structures, since it tells SAM the extent

Scored against the hand-traced path: what fraction of the returned mask lies
within a few pixels of that path (precision), and how much of the span it
covers (recall). A mask that grabs the wall behind the rope scores low on the
first even if it covers the rope.
"""
import os
import numpy as np
import torch
from PIL import Image, ImageDraw
from scipy import ndimage

os.environ.setdefault('HF_HOME', os.path.dirname(os.path.abspath(__file__)) + '/hf')
from transformers import SamModel, SamProcessor

W, H = 1920, 1080
PATH = [(285, 484), (350, 480), (420, 469), (500, 459), (580, 452), (640, 446), (700, 440)]

img = Image.open('v2.png').convert('RGB')
model = SamModel.from_pretrained('facebook/sam-vit-huge').eval()
proc = SamProcessor.from_pretrained('facebook/sam-vit-huge')
torch.set_num_threads(os.cpu_count() or 4)

enc = proc(img, return_tensors='pt')
with torch.no_grad():
    emb = model.get_image_embeddings(enc['pixel_values'])

ref = Image.new('L', (W, H), 0)
ImageDraw.Draw(ref).line(PATH, fill=255, width=7, joint='curve')
ref = np.asarray(ref) > 0
near = ndimage.binary_dilation(ref, np.ones((9, 9)))     # rope +/- a few px

TRIALS = {
    'one point':   dict(input_points=[[[[500, 459]]]], input_labels=[[[1]]]),
    'many points': dict(input_points=[[[[330, 481], [420, 469], [500, 459],
                                        [580, 452], (660, 444)]]],
                        input_labels=[[[1, 1, 1, 1, 1]]]),
    'box':         dict(input_boxes=[[[285, 436, 700, 492]]]),
}

os.makedirs('sam', exist_ok=True)
arr = np.asarray(img)
print(f'{"prompt":12s} {"cand":5s} {"iou":>6s} {"px":>8s} {"precision":>10s} {"recall":>8s}')
for name, kw in TRIALS.items():
    kw = {k: [[[list(p) for p in v[0][0]]]] if k == 'input_points' else v
          for k, v in kw.items()}
    inp = proc(img, return_tensors='pt', **kw)
    inp.pop('pixel_values')
    with torch.no_grad():
        out = model(image_embeddings=emb, multimask_output=True, **inp)
    masks = proc.image_processor.post_process_masks(
        out.pred_masks.cpu(), inp['original_sizes'].cpu(),
        inp['reshaped_input_sizes'].cpu())[0][0].numpy()
    scores = out.iou_scores[0, 0].detach().numpy()
    for i, m in enumerate(masks):
        n = int(m.sum())
        prec = (m & near).sum() / max(n, 1)
        rec = (m & ref).sum() / ref.sum()
        print(f'{name:12s} {i:<5d} {scores[i]:6.3f} {n:8d} {prec:9.1%} {rec:7.1%}')
        tag = f'rope_{name.replace(" ", "")}_{i}'
        Image.fromarray((m * 255).astype(np.uint8)).save(f'sam/{tag}.png')
        ov = arr.copy()
        ov[m] = (ov[m] * 0.4 + np.array([255, 40, 90]) * 0.6).astype(np.uint8)
        Image.fromarray(ov[400:540, 260:740]).save(f'sam/ov_{tag}.png')
