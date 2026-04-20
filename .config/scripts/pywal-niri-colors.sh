#!/usr/bin/env bash
# Update niri border colors from pywal/wallust colors

COLORS="$HOME/.cache/wal/colors.json"
CONFIG="$HOME/.config/niri/config.kdl"

if [ ! -f "$COLORS" ]; then
    echo "wal colors.json not found" >&2
    exit 1
fi

active=$(jq -r '.colors.color4' "$COLORS")
inactive=$(jq -r '.special.background' "$COLORS")

# Update marked lines in config.kdl (sed targets the pywal comment markers)
sed -i "s|active-color \"#[^\"]*\" // pywal-active|active-color \"${active}\" // pywal-active|" "$CONFIG"
sed -i "s|inactive-color \"#[^\"]*\" // pywal-inactive|inactive-color \"${inactive}\" // pywal-inactive|" "$CONFIG"

# Reload niri config if running
if niri msg action load-config-file 2>/dev/null; then
    :
fi
