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
overview=$(jq -r '.special.background' "$COLORS")

# Abort if any value missing/null — prevents writing empty strings to config
for v in active inactive overview; do
    val="${!v}"
    if [ -z "$val" ] || [ "$val" = "null" ]; then
        echo "pywal color '$v' empty or null — aborting" >&2
        exit 1
    fi
done

# Update marked lines in config.kdl (sed targets the pywal comment markers)
# Regex matches any quoted value (incl. empty) so script self-heals if config got blanked
sed -i "s|active-color \"[^\"]*\" // pywal-active|active-color \"${active}\" // pywal-active|" "$CONFIG"
sed -i "s|inactive-color \"[^\"]*\" // pywal-inactive|inactive-color \"${inactive}\" // pywal-inactive|" "$CONFIG"
sed -i "s|background-color \"[^\"]*\" // pywal-overview|background-color \"${overview}\" // pywal-overview|" "$CONFIG"

# Reload niri config if running
if niri msg action load-config-file 2>/dev/null; then
    :
fi
