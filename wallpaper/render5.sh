#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
img() { echo -loop 1 -framerate 60 -i "$1"; }

# h264 8-bit is the default because it is what the iGPU can decode in hardware.
# It is also about 2x cheaper to decode than the HEVC 10-bit encode either way,
# hardware or software, which is what stopped mpvpaper dropping frames.
# CODEC_ARGS="$HEVC" ./render5.sh to go back.
#
# CODEC_ARGS picks the encoder, and the honest answer is that it barely matters.
# Measured on a Ryzen 5 3600, 6s of output:
#
#     filtergraph only (-f null)   66.3s wall, 389s CPU
#     + x264 -preset medium        67.4s
#     + x264 -preset slow          69.8s
#
# The ENCODER IS 5% OF THE WALL TIME. Nothing in the graph — maskedmerge,
# displace, blend, 60 timed overlays — has a CUDA equivalent in ffmpeg, so a GPU
# can take the encode and nothing else, which caps NVENC's benefit at those 3.5
# seconds in 70. Do not reboot into a driver fix expecting a faster render, and
# do not reach for H264_FAST either; -preset slow costs 2.4s in 70 and is the
# only one of these knobs that changes the output.
#
# The headroom that IS there: the filtergraph sustains ~5.9 of this machine's 12
# cores. Using the rest means splitting the timeline across processes, and every
# scrolling layer's phase would have to be re-derived per segment — a wrong
# offset there does not fail, it just makes the loop jump. Not attempted.
H264='-c:v libx264 -preset slow -crf 15 -pix_fmt yuv420p'
H264_FAST='-c:v libx264 -preset medium -crf 15 -pix_fmt yuv420p'
NVENC='-c:v h264_nvenc -preset p6 -tune hq -rc vbr -cq 19 -b:v 0 -pix_fmt yuv420p'
HEVC='-c:v libx265 -preset medium -crf 16 -pix_fmt yuv420p10le -tag:v hvc1 -x265-params log-level=error'

# The screen program is optional and therefore LAST, so that its presence does
# not renumber anything else. graph.py keys off the same file, so the two agree
# by construction rather than by being edited together.
SCREEN=()
if [ -f screen/meta.sh ]; then
  . screen/meta.sh
  # No -framerate here: that is an image2 demuxer option, and this input is a
  # container that already carries its own rate. The other sequence inputs need
  # it precisely because PNGs on disk do not.
  SCREEN=(-stream_loop -1 -i screen/screen.mkv)
  echo "screen: ${SCREEN_LOOP}s program, ${SCREEN_FRAMES} frames @ ${SCREEN_FPS}fps"
fi

# A stale graph is silently WRONG rather than broken: the input indices still
# resolve, they just resolve to the wrong images, and you find out 90 minutes
# later. Cheap to check, so check.
if [ ! graph5.gen.txt -nt graph.py ] || \
   { [ -f screen/meta.sh ] && [ ! graph5.gen.txt -nt screen/meta.sh ]; }; then
  echo "graph5.gen.txt is older than graph.py or screen/meta.sh" >&2
  echo "  ./py.sh graph.py" >&2
  exit 1
fi

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
  "${SCREEN[@]}" \
  -filter_complex_script graph5.gen.txt -map '[out]' \
  -t 288 -r 60 -an ${FFMPEG_EXTRA:-} \
  ${CODEC_ARGS:-$H264} -movflags +faststart "${OUT:-hq2.mp4}"
ls -la "${OUT:-hq2.mp4}"
