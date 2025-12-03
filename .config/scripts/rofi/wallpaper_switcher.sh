#!/usr/bin/env bash

WALLDIR="$HOME/Pictures/wallpaper"
SCRIPTDIR="$HOME/.config/scripts"

SELECTED=$(find $WALLDIR\
    -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \)  \
    | shuf |
    while read -r img; do
        echo -en "$img\0icon\x1f$img\n"
    done \
| rofi -dmenu -show-icons -theme "$HOME/.config/rofi/wallselect.rasi" -p ">")

# Exit if nothing is selected
[ -z "$SELECTED" ] && exit 0

# notify-send "new wallpaper: $(basename "$SELECTED")"

# Set wallpaper with swww
swww img -t grow --transition-duration 2 "$SELECTED"

# Symlink for wallpaper (currently used in neofetch)
ln -sf "$SELECTED" "$HOME/.cache/current_wallpaper"
$SCRIPTDIR/rofi/wallpaper-preview.sh

# Generate colors using pywal
wal -i "$SELECTED" -n -q

# Reload SwayNC
if command -v swaync-client >/dev/null 2>&1; then
  swaync-client --reload
fi

# Reload Kitty
if pgrep -x kitty >/dev/null; then
  pkill -USR1 kitty
fi

# Reload Starship
if command -v starship-color-gen.sh >/dev/null 2>&1; then
  $SCRIPTDIR/starship-color-gen.sh
fi

# New borders with Hyprland
$SCRIPTDIR/pywal-hyprland-colors.sh

# SwayNC
swaync-client -rs >/dev/null 2>&1

# Reload pywalfox
pywalfox update

exit 0
