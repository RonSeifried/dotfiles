#!/bin/bash

WAL_COLORS="$HOME/.cache/wal/colors.json"
STARSHIP_WAL="$HOME/.config/starship/palettes/wal.toml"

jq -r '
  .colors | to_entries |
  map("[\( .key )] = \"\( .value )\"") |
  join("\n")
' "$WAL_COLORS" > "$STARSHIP_WAL"

echo "Starship palette updated from pywal."
