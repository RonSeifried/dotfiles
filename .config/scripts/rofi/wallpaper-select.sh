#!/usr/bin/env bash
set -euo pipefail

# ---- paths / sizes (keep in sync with your theme) ----
WALL_DIR="${WALL_DIR:-$HOME/Pictures/wallpaper}"
CACHE="$HOME/.cache/rofi"
SYMLINK="$CACHE/current_wallpaper"
PREVIEW="$CACHE/current_wallpaper_preview.png"
THUMBS="$CACHE/wall_thumbs"
PREV_W=${PREV_W:-520}   # <- imagebox width in your theme
PREV_H=${PREV_H:-520}   # <- imagebox height in your theme

mkdir -p "$CACHE" "$THUMBS"

# ---- helpers ----
have() { command -v "$1" >/dev/null 2>&1; }

mk_preview() {
  local src="$1"
  # Exact canvas -> prevents tiling in Rofi
  if have magick; then
    magick "$src" -auto-orient -resize "${PREV_W}x${PREV_H}^" \
      -gravity center -extent "${PREV_W}x${PREV_H}" "$PREVIEW"
  elif have convert; then
    convert "$src" -auto-orient -resize "${PREV_W}x${PREV_H}^" \
      -gravity center -extent "${PREV_W}x${PREV_H}" "$PREVIEW"
  else
    # last-ditch: copy; (might tile if smaller)
    cp -f "$src" "$PREVIEW"
  fi
}

mk_thumb() {
  local src="$1" base out
  base="$(basename "$src")"
  out="$THUMBS/${base%.*}.png"
  [ -f "$out" ] && return 0
  if have magick; then
    magick "$src" -auto-orient -resize '64x64^' -gravity center -extent 64x64 "$out"
  elif have convert; then
    convert "$src" -auto-orient -resize '64x64^' -gravity center -extent 64x64 "$out"
  else
    # no ImageMagick – use the source as icon (may be large)
    ln -sf "$src" "$out"
  fi
}

set_wall() {
  local img="$1"
  # set the background
  if have swww; then
    swww img -t grow --transition-duration 2 --invert-y 0 "$img"
  elif have swaybg; then
    pkill -x swaybg 2>/dev/null || true
    swaybg -m fill -i "$img" &
  fi
  # update symlink + preview
  ln -sf "$img" "$SYMLINK"
  mk_preview "$img"
}

# ---- Rofi script mode protocol ----
# Print entries with per-row icon using \x00icon\x1f and store absolute path in \x00info\x1f
print_list() {
  # shellcheck disable=SC2044
  for f in $(find "$WALL_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print0 | sort -z | xargs -0 -I{} printf '%s\0' "{}"); do
    path="${f%$'\0'}"
    base="$(basename "$path")"
    mk_thumb "$path"
    thumb="$THUMBS/${base%.*}.png"
    printf '%s\x00icon\x1f%s\x00info\x1f%s\n' "$base" "$thumb" "$path"
  done
}

# ROFI passes selection/meta via env + stdin
RET="${ROFI_RETV:-}"
case "${RET:-0}" in
  ""|0)
    print_list
    ;;
  1)
    # selected entry: rofi puts the chosen row on stdin.
    # We need its meta info (absolute path) from ROFI_INFO.
    read -r CHOICE
    IMG="${ROFI_INFO:-}"
    # Fallback: reconstruct absolute path from list label if no info
    [ -z "$IMG" ] && IMG="$WALL_DIR/$CHOICE"
    [ -f "$IMG" ] && set_wall "$IMG"
    ;;
  10)
    # custom key preview into external imv (optional)
    # requires: bind kb-custom-1 in your rofi config if you want it
    read -r CHOICE
    IMG="${ROFI_INFO:-}"
    [ -z "$IMG" ] && IMG="$WALL_DIR/$CHOICE"
    if have imv; then
      pkill -f 'imv --class rofi-preview' 2>/dev/null || true
      imv -n --class rofi-preview "$IMG" >/dev/null 2>&1 &
    fi
    # re-list to stay in the menu
    print_list
    ;;
  *)
    # ignore other return codes
    ;;
esac
