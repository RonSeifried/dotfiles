#!/usr/bin/env bash
# Clipboard Manager – Rofi frontend for cliphist
# Requires: cliphist, wl-clipboard, rofi

THEME="$HOME/.config/rofi/utility.rasi"

case "${1:-}" in
    --clear)
        cliphist wipe
        notify-send "Clipboard" "History cleared" -t 2000
        ;;
    --delete)
        cliphist list | rofi -dmenu -i -p "Delete" -theme "$THEME" | cliphist delete
        ;;
    *)
        selected=$(cliphist list | rofi -dmenu -i -p "Clipboard" -theme "$THEME" \
            -theme-str 'listview { lines: 12; } window { width: 600px; }')
        [[ -z "$selected" ]] && exit 0
        echo "$selected" | cliphist decode | wl-copy
        ;;
esac

exit 0
