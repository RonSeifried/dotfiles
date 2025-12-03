#!/usr/bin/env bash
# Creates a preview exactly matching the imagebox size (see general.rasi width).
set -euo pipefail

SRC="${HOME}/.cache/current_wallpaper"   # your symlink (from the swww script)
OUT="${HOME}/.cache/rofi/current_wallpaper_preview.png"

# must match imagebox width; height is 3:2 to look balanced next to the list
PANE_W=520
PANE_H=520


mkdir -p "$(dirname "$OUT")"
magick "$SRC" -resize "${PANE_W}x${PANE_H}^" -gravity center \
       -extent "${PANE_W}x${PANE_H}" $OUT

