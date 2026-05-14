#!/usr/bin/env bash
# Pick a window via niri's IPC pointer prompt, then screenshot it.
# niri does the framing itself (decoration-aware, no slurp drift) and follows
# the configured screenshot-path + clipboard behavior.

set -e

wid=$(niri msg -j pick-window 2>/dev/null | jq -r '.id // empty')

# Empty id = cancelled (Esc / right-click). Silent exit.
[[ -z "$wid" ]] && exit 0

niri msg action screenshot-window --id "$wid"
