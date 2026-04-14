#!/bin/bash

WAL_COLORS="$HOME/.cache/wal/colors.json"
STARSHIP_BASE="$HOME/.config/starship/starship.toml.base"
STARSHIP_TOML="$HOME/.config/starship/starship.toml"

# Only run if both files exist
if [[ ! -f "$WAL_COLORS" || ! -f "$STARSHIP_BASE" ]]; then
    exit 0
fi

# Create a fresh starship.toml from the base file
cp "$STARSHIP_BASE" "$STARSHIP_TOML"

# Append the new generated palette block
{
  echo ""
  echo "[palettes.wal]"
  jq -r '
    (.colors + .special) | to_entries |
    map("\(.key) = \"\(.value)\"") |
    join("\n")
  ' "$WAL_COLORS"
} >> "$STARSHIP_TOML"

echo "Starship palette generated from base file." >&2
