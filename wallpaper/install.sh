#!/usr/bin/env bash
# Install a render as the animated wallpaper, atomically.
#
# Do NOT cp over the live file. mpvpaper runs with --loop-file=inf, which makes
# mpv re-read the file at the end of every loop; cp truncates and rewrites in
# place, so the player loops straight into half-written bytes and dies with
# "Invalid NAL unit size". mv within the same filesystem is a rename, so a
# running player keeps reading the old inode until the service restarts.
#
# The render does not have to have been made on this machine. Nothing about it
# is host-specific — it is 1920x1080 h264 and every Linux machine here has a
# 1920x1080 output — so the way to put the wallpaper on a second machine is to
# carry this file to it and run this script. No rebuild is needed: the mpvpaper
# unit already exists everywhere and is skipped by ConditionPathExists until the
# file turns up. See README.md.
set -e
# Resolve the source BEFORE the cd, or a relative path silently resolves against
# wallpaper/ instead of the caller's directory — which matters now that the
# usual source is a USB stick rather than a sibling file.
src=$(realpath -e "${1:?usage: install.sh <render.mp4>}")
cd "$(dirname "$0")"
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
