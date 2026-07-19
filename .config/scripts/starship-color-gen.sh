#!/bin/bash
# Regenerate starship.toml from base + pywal palette.
# Also emits ink_color* aliases (per-bg luminance-aware fg). Base config
# references these so segment text stays readable across palette swaps —
# avoids hard-coded "fg:black" failing on dark wallust palettes.

set -u

WAL_COLORS="$HOME/.cache/wal/colors.json"
STARSHIP_BASE="$HOME/.config/starship/starship.toml.base"
STARSHIP_TOML="$HOME/.config/starship/starship.toml"

if [[ ! -f "$WAL_COLORS" || ! -f "$STARSHIP_BASE" ]]; then
    exit 0
fi

cp "$STARSHIP_BASE" "$STARSHIP_TOML"

# Pick "color0" or "color15" hex as readable fg over given bg hex.
# WCAG sRGB relative luminance, threshold 0.45.
ink_for() {
  awk -v hex="${1#\#}" -v c0="$2" -v c15="$3" '
    function lin(v) { v=v/255.0; if (v<=0.03928) return v/12.92; return ((v+0.055)/1.055)^2.4 }
    BEGIN {
      r = strtonum("0x" substr(hex,1,2))
      g = strtonum("0x" substr(hex,3,2))
      b = strtonum("0x" substr(hex,5,2))
      L = 0.2126*lin(r) + 0.7152*lin(g) + 0.0722*lin(b)
      print (L > 0.45) ? c0 : c15
    }'
}

c0=$(jq -r '.colors.color0'  "$WAL_COLORS")
c15=$(jq -r '.colors.color15' "$WAL_COLORS")

{
  echo ""
  echo "[palettes.wal]"
  jq -r '
    (.colors + .special) | to_entries |
    map("\(.key) = \"\(.value)\"") |
    join("\n")
  ' "$WAL_COLORS"

  for k in color1 color2 color3 color4 color5 color6 color7 \
           color8 color9 color10 color11 color12 color13 color14 color15; do
    hex=$(jq -r ".colors.${k}" "$WAL_COLORS")
    ink=$(ink_for "$hex" "$c0" "$c15")
    echo "ink_${k} = \"${ink}\""
  done
} >> "$STARSHIP_TOML"

echo "Starship palette generated from base file." >&2
