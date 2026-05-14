#!/usr/bin/env bash
# Update niri border + overview backdrop colors from wallust palette

COLORS="$HOME/.cache/wal/colors.json"
CONFIG="$HOME/.config/niri/includes/layout.kdl"

# Wallust slot for overview backdrop (color8 = bright-black, elevated surface).
# Override via env: OVERVIEW_COLOR_KEY=color1 (warm accent) etc.
OVERVIEW_COLOR_KEY="${OVERVIEW_COLOR_KEY:-color8}"

if [ ! -f "$COLORS" ]; then
    echo "wal colors.json not found" >&2
    exit 1
fi

active=$(jq -r '.colors.color6' "$COLORS")
# Slot choice mirrors quickshell/Colors.qml: color6 = accent (vibrant readable),
# color8 = bgVariant (medium tint). color0/special.background often collapses
# to near-pure black with salience+dark style; using color8 keeps niri inactive
# border + overview bg visually wallpaper-bound.
inactive=$(jq -r '.colors.color8' "$COLORS")
layout_bg=$(jq -r '.colors.color8' "$COLORS")
overview_backdrop=$(jq -r ".colors.${OVERVIEW_COLOR_KEY}" "$COLORS")
# color1 = warm/error slot (mirrors Colors.error in quickshell)
urgent_base=$(jq -r '.colors.color1' "$COLORS")

# Abort if any value missing/null — prevents writing empty strings to config
for v in active inactive layout_bg overview_backdrop urgent_base; do
    val="${!v}"
    if [ -z "$val" ] || [ "$val" = "null" ]; then
        echo "color '$v' empty or null — aborting" >&2
        exit 1
    fi
done

# Recent-windows highlight = accent + 60% alpha (overlay on focused thumbnail)
recent_highlight="${active}99"
# Urgent = error/warm slot + 80% alpha (stronger than active for attention)
recent_urgent="${urgent_base}cc"

# Update marked lines in includes/layout.kdl (sed targets the pywal comment markers)
# Regex matches any quoted value (incl. empty) so script self-heals if config got blanked
sed -i "s|active-color \"[^\"]*\" // pywal-active|active-color \"${active}\" // pywal-active|" "$CONFIG"
sed -i "s|inactive-color \"[^\"]*\" // pywal-inactive|inactive-color \"${inactive}\" // pywal-inactive|" "$CONFIG"
sed -i "s|background-color \"[^\"]*\" // pywal-overview|background-color \"${layout_bg}\" // pywal-overview|" "$CONFIG"
sed -i "s|backdrop-color \"[^\"]*\" // pywal-overview-backdrop|backdrop-color \"${overview_backdrop}\" // pywal-overview-backdrop|" "$CONFIG"
sed -i "s|active-color \"[^\"]*\" // pywal-recent-highlight|active-color \"${recent_highlight}\" // pywal-recent-highlight|" "$CONFIG"
sed -i "s|urgent-color \"[^\"]*\" // pywal-recent-urgent|urgent-color \"${recent_urgent}\" // pywal-recent-urgent|" "$CONFIG"

# Reload niri config if running
if niri msg action load-config-file 2>/dev/null; then
    :
fi
