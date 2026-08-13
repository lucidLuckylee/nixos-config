#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
img() { echo -loop 1 -framerate 60 -i "$1"; }

# h264 8-bit is the default because it is what the iGPU can decode in hardware.
# It is also about 2x cheaper to decode than the HEVC 10-bit encode either way,
# hardware or software, which is what stopped mpvpaper dropping frames.
# CODEC_ARGS="$HEVC" ./render5.sh to go back.
# CODEC_ARGS picks the encoder. Measured on a Ryzen 5 5500U the whole pipeline
# runs at ~4.3 cores, so it is already threaded; the encoder is only part of
# that and the FILTERGRAPH is the rest. Nothing in the graph — maskedmerge,
# displace, blend, 60 timed overlays — has a CUDA equivalent in ffmpeg, so a
# GPU can take the encode and nothing else. Expect a useful speedup from NVENC,
# not a transformative one; more/faster CPU cores matter at least as much.
H264='-c:v libx264 -preset slow -crf 15 -pix_fmt yuv420p'
H264_FAST='-c:v libx264 -preset medium -crf 15 -pix_fmt yuv420p'
NVENC='-c:v h264_nvenc -preset p6 -tune hq -rc vbr -cq 19 -b:v 0 -pix_fmt yuv420p'
HEVC='-c:v libx265 -preset medium -crf 16 -pix_fmt yuv420p10le -tag:v hvc1 -x265-params log-level=error'

# INPUT ORDER MUST MATCH graph.py's `I` table. The graph is generated; if you
# add an input here, add it there and regenerate rather than renumbering by hand.
ffmpeg -y -hide_banner -loglevel error \
  $(img v2.png) $(img mask_cyan_hd.png) $(img mask_amber_hd.png) \
  $(img glow_hd.png) $(img blob_hd.png) $(img blob2_hd.png) \
  $(img mask_port.png) \
  $(img rain_far.png) $(img rain_mid.png) $(img rain_near.png) \
  $(img rain_sprinkle.png) $(img rain_heavy.png) \
  $(img mask_screen.png) $(img bar.png) \
  -framerate 60 -stream_loop -1 -i steam/steam_%03d.png \
  $(img drops_x.png) $(img drops_y.png) $(img drops_spec.png) \
  -framerate 30 -stream_loop -1 -i drip/drip_%04d.png \
  $(img drip_front.png) \
  $(img fog.png) $(img flash.png) \
  $(img led_cyan.png) $(img led_red.png) $(img led_green.png) \
  -filter_complex_script graph5.gen.txt -map '[out]' \
  -t 288 -r 60 -an \
  ${CODEC_ARGS:-$H264} -movflags +faststart "${OUT:-hq2.mp4}"
ls -la "${OUT:-hq2.mp4}"
