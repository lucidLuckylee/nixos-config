#!/usr/bin/env bash
# Upscale and grade a still wallpaper to an output's native resolution.
#
#   ./grade.sh ~/Downloads/art.jpg 1680x1050 ../home/wallpaper2.jpg
#
# This is the recipe behind home/wallpaper.jpg, written down. It previously
# existed only in the body of commit db6d895, which is a fine place to record
# WHY something was done and a poor one to keep something you have to run again
# — the second monitor needed the same treatment at a different size and the
# recipe had to be excavated from git log to do it.
#
# Sway scales the background at display time, and a source smaller than the
# output gets stretched: 1200x727 on a 1920x1080 screen was a 1.6x stretch, and
# that softness read as flatness as much as the tonality did. So the image is
# rendered at native resolution up front.
#
#   1. ESRGAN x4, then downsample. Upscaling well past the target and coming
#      back down is deliberate: the downsample averages away the smearing and
#      over-sharpened edges the network invents, which at 1:1 look like plastic.
#      Note that gowall's own `upscale` subcommand is NOT used — it wants to
#      fetch and set up its own realesrgan binary, which on NixOS is a
#      dynamically linked blob that will not run. nixpkgs' package works.
#   2. Fit to the output by covering and centre-cropping, never by stretching.
#      A 4:3 source on a 16:10 screen loses 17% of its height; that is the price
#      of not distorting it.
#   3. SIGMOIDAL contrast, not linear. It steepens the midtones while leaving
#      the deep shadows and the neon highlights unclipped, which matters because
#      both of these paintings are mostly dark with small blown-out emitters —
#      linear contrast crushes the former and clips the latter.
#   4. A 30% blend with the same image mapped to the terminal palette. Full
#      strength reads "too hot" (that was commit e7fafe2, which reverted an
#      earlier all-or-nothing palette map back to the untouched artwork); 30%
#      just pulls the reds and pipes toward the theme without posterising.
#
# The palette is read out of home/colors.nix rather than transcribed, because a
# hand-copied list of sixteen hex values is a thing that silently drifts from
# the theme it is supposed to match.
set -e
cd "$(dirname "$0")"

src="${1:?usage: grade.sh SRC WIDTHxHEIGHT OUT}"
size="${2:?usage: grade.sh SRC WIDTHxHEIGHT OUT}"
out="${3:?usage: grade.sh SRC WIDTHxHEIGHT OUT}"

SIGMOID=${SIGMOID:-3.5}       # sigmoidal contrast strength
MIDPOINT=${MIDPOINT:-0.45}    # slightly below 0.5: these paintings are dark,
                              # so the interesting tones sit under the middle
SATURATION=${SATURATION:-18}
PALETTE=${PALETTE:-30}        # percent of the palette-mapped image blended back
COLORS=${COLORS:-../home/colors.nix}

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mg() { nix shell nixpkgs#imagemagick -c magick "$@"; }
gw() { gowall "$@" --yes --preview false >/dev/null; }

printf '%s\n' "$(nix shell nixpkgs#imagemagick -c identify -format '%wx%h' "$src") -> $size"

# 1. upscale. Slow without a working GPU: realesrgan runs on Vulkan, and if
#    vulkaninfo reports llvmpipe rather than your card then it is on the CPU and
#    a 1MP image takes ~25 minutes instead of ~15 seconds. UPSCALE=0 skips this,
#    for iterating on the grade or for a source already at native resolution —
#    the tonality is the part you will want to run more than once.
if [ "${UPSCALE:-1}" = 0 ]; then
  cp "$src" "$tmp/up.png"
else
  nix shell nixpkgs#realesrgan-ncnn-vulkan -c realesrgan-ncnn-vulkan \
    -i "$src" -o "$tmp/up.png" -n realesrgan-x4plus -s 4 -t 200
fi

# 2. cover and centre-crop
mg "$tmp/up.png" -resize "$size^" -gravity center -extent "$size" "$tmp/fit.png"

# 3. tonality
gw effects contrast "$tmp/fit.png" --mode sigmoid -s "$SIGMOID" -p "$MIDPOINT" \
   --output "$tmp/con.png"
gw effects saturation "$tmp/con.png" -p "$SATURATION" --output "$tmp/sat.png"

# 4. palette blend, at PALETTE percent.
#    The palette is EVALUATED out of colors.nix, not grepped for #rrggbb. That
#    file also carries an `accent` block of semantic UI roles — panel fills,
#    border lines, the raster dot — and those are surfaces rather than palette,
#    so a regex over the whole file sweeps in a dozen near-identical dark teals
#    and drags the blend toward them. `colors` alone is foreground, background
#    and the sixteen ANSI entries, which is what the recipe has always meant.
nix eval --json --file "$COLORS" colors > "$tmp/colors.json"
python3 - "$tmp/colors.json" "$tmp/theme.json" <<'PY'
import json, sys


def walk(v):
    if isinstance(v, str):
        yield v
    elif isinstance(v, dict):
        for x in v.values():
            yield from walk(x)


c = json.load(open(sys.argv[1]))
json.dump({"name": "nixos-colors", "colors": sorted({h.lower() for h in walk(c)})},
          open(sys.argv[2], 'w'))
PY
gw convert "$tmp/sat.png" -t "$tmp/theme.json" --output "$tmp/pal.png"
mg "$tmp/sat.png" "$tmp/pal.png" -alpha off \
   -compose blend -define compose:args="$PALETTE" -composite -quality 92 "$out"

nix shell nixpkgs#imagemagick -c identify "$out"
