#!/usr/bin/env bash
# Record the bar on the live Sway session while the pointer hovers each given
# x position, then split the video into frames and contact sheets.
#   record.sh <outdir> [x ...]
set -euo pipefail

out=$1; shift
xs=(${@:-1600 1690 1855})
region=${REGION:-"1300,0 620x320"}
src=$(cd "$(dirname "$0")/.." && pwd)
store=$(systemctl --user show quickshell -p ExecStart --value | grep -o '/nix/store/[^ ]*-quickshell-config')

rm -rf "$out"; mkdir -p "$out/config" "$out/frames"
ln -s "$src"/*.qml "$out/config/"
for f in Theme Paths Session; do ln -s "$store/$f.qml" "$out/config/"; done

systemctl --user stop quickshell
qs -p "$out/config/shell.qml" >"$out/qs.log" 2>&1 &
shell=$!
trap 'kill $shell 2>/dev/null || true; systemctl --user start quickshell' EXIT
sleep 1

hover() { swaymsg seat - cursor set "$1" "$2" >/dev/null; swaymsg seat - cursor move 1 0 >/dev/null; }
nix run nixpkgs#wf-recorder -- -y -g "$region" -f "$out/rec.mp4" >"$out/wf.log" 2>&1 &
rec=$!; sleep 0.5
for x in "${xs[@]}"; do hover "$x" 14; sleep 0.9; done
hover 960 700; sleep 0.7
kill -INT $rec; wait $rec || true

ffmpeg -loglevel error -y -i "$out/rec.mp4" -vf fps=20 "$out/frames/f%03d.png"
n=$(ls "$out/frames" | wc -l)
for ((i = 1; i + 15 <= n; i += 16)); do
    ffmpeg -loglevel error -y -start_number "$i" -i "$out/frames/f%03d.png" -frames:v 1 \
        -vf "crop=400:120:220:0,tile=2x8" "$out/sheet-$(printf %03d "$i").png"
done
echo "$out"
grep -i error "$out/qs.log" || true
