#!/usr/bin/env bash
# Sanity-check a render before installing it.
#
#   loop seam    last frame vs first frame. The wallpaper loops forever, so a
#                visible jump here is the one artefact a viewer is guaranteed to
#                notice. Every effect period must divide the loop length.
#   vs still     first frame vs the plate. Frame 0 should be the still, so that
#                when mpvpaper starts there is no jump from the swaybg fallback
#                underneath it.
#
# The RMSE is computed in numpy rather than scraped from ffmpeg's psnr filter,
# whose stderr format differs between builds and silently yielded nothing.
set -e
cd "$(dirname "$0")"
f="${1:?usage: verify.sh <render.mp4>}"
dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f")
last=$(awk -v d="$dur" 'BEGIN{printf "%.4f", d - 1/60}')

ffmpeg -v error -i "$f" -frames:v 1 -update 1 -y /tmp/_v_first.png
ffmpeg -v error -ss "$last" -i "$f" -frames:v 1 -update 1 -y /tmp/_v_last.png

./py.sh -c "
import numpy as np
from PIL import Image
def rmse(a, b):
    a = np.asarray(Image.open(a).convert('RGB'), np.float32)
    b = np.asarray(Image.open(b).convert('RGB'), np.float32)
    return np.sqrt(((a - b) ** 2).mean()) / 255 * 100
print(f'loop seam   {rmse(\"/tmp/_v_first.png\", \"/tmp/_v_last.png\"):.2f}%')
print(f'vs still    {rmse(\"/tmp/_v_first.png\", \"v2.png\"):.2f}%')
"
ffprobe -v error -show_entries format=duration,size \
  -show_entries stream=codec_name,pix_fmt,width,height,r_frame_rate \
  -of default=nw=1 "$f"
