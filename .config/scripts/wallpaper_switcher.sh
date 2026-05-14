#!/usr/bin/env bash
# Wallpaper Switcher — backend for the Quickshell WallpaperPicker.
# Selection UI lives in qs (.config/quickshell/menus/WallpaperPicker.qml);
# this script handles apply/cycle/random/symlink + wallust regen.

WALLDIR="${WALLPAPER_DIR:-$HOME/Pictures/wallpaper}"
CACHE_DIR="$HOME/.cache"
THUMB_DIR="$CACHE_DIR/wallpaper-thumbs"

mkdir -p "$THUMB_DIR"

# Apply wallpaper and regenerate palette.
#
# When invoked from the quickshell picker (--apply) it shows its own "Applying"
# badge — the intermediate notify-send is suppressed by default (QUIET_APPLY=1).
# Pass --apply <path> --notify to force the toast back on.
apply_wallpaper() {
    local selected="$1"
    local quiet="${QUIET_APPLY:-0}"

    if [[ ! -f "$selected" ]]; then
        notify-send "Wallpaper Switcher" "File not found: $selected" -u critical
        return 1
    fi

    if [[ "$quiet" != "1" ]]; then
        notify-send "Wallpaper" "Applying: $(basename "$selected")" -t 2000
    fi

    if command -v awww &>/dev/null; then
        pgrep -x awww-daemon >/dev/null || { awww-daemon & sleep 0.3; }
        awww img "$selected" --transition-type grow --transition-duration 2 --transition-pos center
    elif command -v swaybg &>/dev/null; then
        pkill -x swaybg 2>/dev/null || true
        swaybg -m fill -i "$selected" &
    else
        notify-send "Wallpaper Switcher" "No wallpaper backend found" -u critical
        return 1
    fi

    ln -sf "$selected" "$CACHE_DIR/current_wallpaper"

    # wallust regenerates colors.json + templates and runs hooks
    # (niri colors, starship, kitty USR1-reload, etc.)
    if command -v wallust &>/dev/null; then
        wallust run -q "$selected"
    fi

    {
        command -v pywalfox &>/dev/null && pywalfox update
    } &>/dev/null &

    if [[ "$quiet" != "1" ]]; then
        notify-send "Wallpaper" "Applied: $(basename "$selected")" -t 3000
    fi
}

get_images() {
    mapfile -t images < <(find "$WALLDIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | sort)
}

case "${1:-}" in
    --apply)
        if [[ "${3:-}" == "--notify" ]]; then
            QUIET_APPLY=0
        else
            QUIET_APPLY="${QUIET_APPLY:-1}"
        fi
        [[ -n "${2:-}" ]] && apply_wallpaper "$2" || { echo "Usage: $0 --apply /path/to/image"; exit 1; }
        ;;
    --random)
        get_images
        [[ ${#images[@]} -gt 0 ]] && apply_wallpaper "${images[$RANDOM % ${#images[@]}]}"
        ;;
    --next|--prev)
        get_images
        current=$(readlink -f "$CACHE_DIR/current_wallpaper" 2>/dev/null || echo "")
        idx=0
        for i in "${!images[@]}"; do
            [[ "${images[$i]}" == "$current" ]] && idx=$i && break
        done
        if [[ "$1" == "--next" ]]; then
            idx=$(( (idx + 1) % ${#images[@]} ))
        else
            idx=$(( (idx - 1 + ${#images[@]}) % ${#images[@]} ))
        fi
        apply_wallpaper "${images[$idx]}"
        ;;
    --clear-cache)
        rm -rf "$THUMB_DIR"
        echo "Thumbnail cache cleared"
        ;;
    --current)
        if [[ -L "$CACHE_DIR/current_wallpaper" ]]; then
            readlink -f "$CACHE_DIR/current_wallpaper"
        else
            echo "No wallpaper set"
            exit 1
        fi
        ;;
    --help|-h|"")
        echo "Wallpaper Switcher"
        echo ""
        echo "Usage: $0 <option>"
        echo ""
        echo "Options:"
        echo "  --apply <path>  Apply specific wallpaper"
        echo "  --random        Apply random wallpaper"
        echo "  --next          Apply next wallpaper in list"
        echo "  --prev          Apply previous wallpaper in list"
        echo "  --current       Print current wallpaper path"
        echo "  --clear-cache   Clear thumbnail cache"
        echo "  --help          Show this help"
        ;;
    *)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
esac

exit 0
