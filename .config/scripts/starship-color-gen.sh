#!/bin/bash

WAL_COLORS="$HOME/.cache/wal/colors.json"
STARSHIP_TOML="$HOME/.config/starship/starship.toml"

# Only run if both files exist
if [[ ! -f "$WAL_COLORS" || ! -f "$STARSHIP_TOML" ]]; then
    exit 0
fi

# We will dynamically replace the [palettes.wal] section in starship.toml
# Everything below [palettes.wal] until the next [ or EOF will be replaced

# 1. Create a temp file with the colors in TOML format
TEMP_PALETTE=$(mktemp)
jq -r '
  .colors | to_entries |
  map("\( .key ) = \"\( .value )\"") |
  join("\n")
' "$WAL_COLORS" > "$TEMP_PALETTE"

# 2. Add special colors too (background, foreground)
jq -r '
  .special | to_entries |
  map("\( .key ) = \"\( .value )\"") |
  join("\n")
' "$WAL_COLORS" >> "$TEMP_PALETTE"

# 3. Use awk to replace the section
awk -v p="$(cat "$TEMP_PALETTE")" '
BEGIN { in_palette=0 }
/^\[palettes.wal\]/ {
    print
    print p
    in_palette=1
    next
}
/^\[/ { in_palette=0 }
!in_palette { print }
' "$STARSHIP_TOML" > "${STARSHIP_TOML}.new"

mv "${STARSHIP_TOML}.new" "$STARSHIP_TOML"
rm "$TEMP_PALETTE"

echo "Starship palette updated inline."
