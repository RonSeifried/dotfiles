#!/usr/bin/env bash
# Pick a color from the screen via niri IPC.
# Copies #RRGGBB to clipboard (wl-copy) and shows a desktop notification.
# Returns silently if the user cancels the pick.

set -euo pipefail

raw=$(niri msg -j pick-color 2>/dev/null || true)
if [[ -z "$raw" || "$raw" == "null" ]]; then
    exit 0
fi

read -r r g b < <(printf '%s' "$raw" | jq -r '
    if (.rgb // null) == null then empty
    else "\(.rgb[0]) \(.rgb[1]) \(.rgb[2])"
    end
') || exit 0

if [[ -z "${r:-}" ]]; then
    exit 0
fi

hex=$(awk -v r="$r" -v g="$g" -v b="$b" \
    'BEGIN { printf "#%02X%02X%02X", int(r*255+0.5), int(g*255+0.5), int(b*255+0.5) }')
rgb_tuple=$(awk -v r="$r" -v g="$g" -v b="$b" \
    'BEGIN { printf "rgb(%d, %d, %d)", int(r*255+0.5), int(g*255+0.5), int(b*255+0.5) }')

printf '%s' "$hex" | wl-copy

notify-send \
    --app-name="Color Picker" \
    --icon=color-select-symbolic \
    --expire-time=4000 \
    "$hex copied" \
    "$rgb_tuple"
