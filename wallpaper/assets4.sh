#!/usr/bin/env bash
# Rain plates at three depths.
#
# The previous version varied only streak LENGTH and opacity, and gave the far
# layer FEWER drops than the near one. That is backwards on both counts, and it
# is why the rain read as one flat sheet: every streak was the same 1px width,
# so nothing said "this one is further away".
#
# What actually separates depth planes, and what this script varies:
#
#   width      generate each plate at a different resolution and scale it to a
#              common 512x1200. A plate drawn at 1024 wide and halved gives
#              sub-pixel streaks; one drawn at 320 wide and scaled up gives fat
#              ones. This is the strongest cue and the old script had none of it.
#   density    distant rain covers more solid angle, so the far plate gets many
#              more seeds, not fewer.
#   length     near streaks blur longer per frame.
#   contrast   distance washes streaks toward the background.
#   softness   the far plate gets a slight blur: atmosphere, and it stops
#              sub-pixel streaks aliasing into a shimmer when scrolled.
#
# Speed is the other half of the parallax and lives in the filtergraph. Those
# speeds must divide the loop: 48s at N px/s over a 1200px tile is seamless
# only when 48N is a multiple of 1200, i.e. N a multiple of 25.
#
# ANGLE has to agree with the direction the plates are SCROLLED, or the rain
# leans one way and travels another — streaks slanted 17 degrees while falling
# straight down, which is what this looked like before. The graph scrolls each
# layer at dx/dy = -0.2133 (the only ratio that lets all three layers wrap
# seamlessly in x over a 512px tile), so the streaks are drawn at the matching
# 12 degrees off vertical, leaning left.
#
# -level 0%,N% STRETCHES values up to white, so using it to "dim" turned the
# blur halo into a milky veil. Alpha is scaled with an explicit multiply.
set -e
cd "$(dirname "$0")"

plate() { # out genwidth genheight threshold blur alpha tint blursigma
  magick -size "$2x$3" xc:black +noise Random -channel R -separate +channel \
    -threshold "$4" -motion-blur "$5"+102 -normalize \
    -resize 512x1200! -evaluate multiply "$6" \
    -blur "0x$8" gp.png
  magick -size 512x1200 xc:"$7" gp.png -alpha off -compose CopyOpacity -composite "$1"
}

#     out             gen w   gen h  threshold  blur  alpha  tint       soften
plate rain_far.png     1024    2400   99.82%    0x14   0.30  '#b9d2ec'   0.7
plate rain_mid.png      640    1500   99.90%    0x18   0.46  '#cfe4f8'   0.35
plate rain_near.png     320     750   99.94%    0x22   0.70  '#e6f2ff'   0
identify rain_far.png rain_mid.png rain_near.png
