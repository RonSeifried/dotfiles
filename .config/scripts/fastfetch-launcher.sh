#!/usr/bin/env bash
# Fastfetch launcher: random ASCII from pool + pywal-colored placeholders.
# ASCII files in ~/.config/fastfetch/ascii/*.txt use $1..$6 markers.

set -eu

ASCII_DIR="$HOME/.config/fastfetch/ascii"
COLORS_JSON="$HOME/.cache/wal/colors.json"
SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")

# Niri's default column is half the output width. A side-by-side logo and the
# full module set cannot fit there, so use a deliberately compact vertical
# layout instead of letting Fastfetch hard-wrap both columns into each other.
cols=$(tput cols 2>/dev/null || printf '120')
if [ "$cols" -lt 92 ]; then
  exec fastfetch --config "$SCRIPT_DIR/../fastfetch/compact.jsonc" "$@"
fi

# Bail to bare fastfetch if pool empty / missing
shopt -s nullglob
files=("$ASCII_DIR"/*.txt)
shopt -u nullglob
if [ "${#files[@]}" -eq 0 ]; then
  exec fastfetch "$@"
fi

pick="${files[RANDOM % ${#files[@]}]}"

# Slot choice mirrors quickshell/zsh: only the readable wallust slots
# (5 = warm secondary, 6 = accent, 7 = textMuted, 8 = bgVariant, 15 = text)
# get rendered as logo colors. Dim slots 1–4 are intentionally skipped — they
# wash out against the terminal bg.
fb="#888888"
if [ -r "$COLORS_JSON" ] && command -v jq >/dev/null 2>&1; then
  read -r c1 c2 c3 c4 c5 c6 < <(
    jq -r '[.colors.color5, .colors.color6, .colors.color7,
            .colors.color8, .colors.color15, .colors.color6] | @tsv' \
       "$COLORS_JSON" 2>/dev/null
  )
  : "${c1:=$fb}" "${c2:=$fb}" "${c3:=$fb}" "${c4:=$fb}" "${c5:=$fb}" "${c6:=$fb}"
else
  c1=$fb c2=$fb c3=$fb c4=$fb c5=$fb c6=$fb
fi

exec fastfetch \
  --logo-type file \
  --logo "$pick" \
  --logo-color-1 "$c1" \
  --logo-color-2 "$c2" \
  --logo-color-3 "$c3" \
  --logo-color-4 "$c4" \
  --logo-color-5 "$c5" \
  --logo-color-6 "$c6" \
  --logo-padding-top 1 \
  --logo-padding-right 2 \
  "$@"
