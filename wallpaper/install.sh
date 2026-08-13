#!/usr/bin/env bash
# Install a render as the animated wallpaper, atomically.
#
# Do NOT cp over the live file. mpvpaper runs with --loop-file=inf, which makes
# mpv re-read the file at the end of every loop; cp truncates and rewrites in
# place, so the player loops straight into half-written bytes and dies with
# "Invalid NAL unit size". mv within the same filesystem is a rename, so a
# running player keeps reading the old inode until the service restarts.
set -e
cd "$(dirname "$0")"
src="${1:?usage: install.sh <render.mp4>}"
dst="$HOME/.local/share/wallpaper/animated.mp4"

ffmpeg -v error -i "$src" -f null - </dev/null   # refuse to install a bad file
mkdir -p "$(dirname "$dst")"
cp "$src" "$dst.new"
mv -f "$dst.new" "$dst"
systemctl --user restart mpvpaper.service
sleep 3
systemctl --user is-active mpvpaper.service
journalctl --user -u mpvpaper.service --since '10 seconds ago' -p warning --no-pager | tail -5
ls -la "$dst"
