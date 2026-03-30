#!/usr/bin/env bash
# Wallpaper Switcher - Complete wallpaper management
# Compatible with Rofi 2.0
# Features: rofi menu, thumbnails, pywal integration, preview generation

# Configuration
WALLDIR="${WALLPAPER_DIR:-$HOME/Pictures/wallpaper}"
CACHE_DIR="$HOME/.cache"
THUMB_DIR="$CACHE_DIR/wallpaper-thumbs"
ROFI_THEME="$HOME/.config/rofi/wallselect.rasi"


# Preview settings (for rofi launcher background)
PREVIEW_OUT="$CACHE_DIR/rofi/current_wallpaper_preview.png"
PREVIEW_WIDTH="${PREVIEW_WIDTH:-520}"
PREVIEW_HEIGHT="${PREVIEW_HEIGHT:-520}"

# Ensure cache directories exist
mkdir -p "$CACHE_DIR/rofi" "$THUMB_DIR"



# Generate preview image for rofi launcher background
generate_preview() {
    local src="$CACHE_DIR/current_wallpaper"

    # Check if source wallpaper exists
    if [[ ! -f "$src" ]] && [[ ! -L "$src" ]]; then
        # Create placeholder
        if command -v magick &>/dev/null; then
            magick -size "${PREVIEW_WIDTH}x${PREVIEW_HEIGHT}" xc:#1d2021 -fill '#ebdbb2' \
                -gravity center -pointsize 24 -annotate 0 "No wallpaper set" "$PREVIEW_OUT"
        elif command -v convert &>/dev/null; then
            convert -size "${PREVIEW_WIDTH}x${PREVIEW_HEIGHT}" xc:#1d2021 -fill '#ebdbb2' \
                -gravity center -pointsize 24 -annotate 0 "No wallpaper set" "$PREVIEW_OUT"
        fi
        return 0
    fi

    # Resolve symlink
    local real_src
    real_src="$(readlink -f "$src" 2>/dev/null || echo "$src")"
    [[ ! -f "$real_src" ]] && return 1

    # Generate preview
    if command -v magick &>/dev/null; then
        magick "$real_src" -auto-orient -resize "${PREVIEW_WIDTH}x${PREVIEW_HEIGHT}^" \
            -gravity center -extent "${PREVIEW_WIDTH}x${PREVIEW_HEIGHT}" "$PREVIEW_OUT"
    elif command -v convert &>/dev/null; then
        convert "$real_src" -auto-orient -resize "${PREVIEW_WIDTH}x${PREVIEW_HEIGHT}^" \
            -gravity center -extent "${PREVIEW_WIDTH}x${PREVIEW_HEIGHT}" "$PREVIEW_OUT"
    else
        cp -f "$real_src" "$PREVIEW_OUT"
    fi
}

# Apply wallpaper and generate colors
apply_wallpaper() {
    local selected="$1"

    if [[ ! -f "$selected" ]]; then
        notify-send "Wallpaper Switcher" "File not found: $selected" -u critical
        return 1
    fi

    notify-send "Wallpaper" "Applying: $(basename "$selected")" -t 2000

    # Set wallpaper with awww
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

    # Update symlink
    ln -sf "$selected" "$CACHE_DIR/current_wallpaper"

    # Step 1: Generate pywal cache files (~/.cache/wal/colors-waybar.css, colors-rofi-dark.rasi, etc.)
    # wal writes ALL the cache files that waybar/rofi/swaync @import from
    if command -v wal &>/dev/null; then
        wal -i "$selected" -n -q -e
    fi

    # Step 2: Run wallust for templates (swayosd CSS) + hooks (hyprland colors, app reloads)
    # wallust does NOT write ~/.cache/wal/ — it only handles its own templates + hooks
    if command -v wallust &>/dev/null; then
        wallust run -q "$selected"
    else
        # Fallback: manual reloads if wallust is not installed
        local pywal_script="$HOME/.config/scripts/pywal-hyprland-colors.sh"
        [[ -x "$pywal_script" ]] && "$pywal_script"
        pgrep -x waybar &>/dev/null && pkill -SIGUSR2 waybar
        command -v swaync-client &>/dev/null && swaync-client -rs
    fi

    # Generate preview for rofi launcher background
    generate_preview &

    # Reload apps not covered by wallust hooks
    {
        pgrep -x kitty &>/dev/null && pkill -USR1 kitty
        command -v pywalfox &>/dev/null && pywalfox update
    } &>/dev/null &

    notify-send "Wallpaper" "Applied: $(basename "$selected")" -t 3000
}

# Show rofi menu
show_menu() {
    if [[ ! -d "$WALLDIR" ]]; then
        notify-send "Wallpaper Switcher" "Directory not found: $WALLDIR" -u critical
        exit 1
    fi

    # Find all images
    mapfile -t images < <(find "$WALLDIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | sort)

    if [[ ${#images[@]} -eq 0 ]]; then
        notify-send "Wallpaper Switcher" "No images found in $WALLDIR" -u critical
        exit 1
    fi

    # Build associative array: basename -> full path
    declare -A path_map
    for img in "${images[@]}"; do
        local bname
        bname=$(basename "$img")
        path_map["$bname"]="$img"
    done

    # Build rofi input
    # Rofi 2.0 dmenu format: text\0icon\x1fpath
    local selected
    if [[ -f "$ROFI_THEME" ]]; then
        selected=$(
            for img in "${images[@]}"; do
                local bname
                bname=$(basename "$img")
                printf '%s\0icon\x1f%s\n' "$bname" "$img"
            done | rofi -dmenu -i -show-icons -theme "$ROFI_THEME" -p ">" -format 's'
        )
    else
        selected=$(
            for img in "${images[@]}"; do
                local bname
                bname=$(basename "$img")
                printf '%s\0icon\x1f%s\n' "$bname" "$img"
            done | rofi -dmenu -i -show-icons -p "Wallpaper" -format 's'
        )
    fi

    # Exit if nothing selected
    [[ -z "$selected" ]] && exit 0

    # Normalize: strip whitespace, control characters
    selected=$(echo "$selected" | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Look up in associative array
    local full_path="${path_map[$selected]}"

    if [[ -n "$full_path" && -f "$full_path" ]]; then
        apply_wallpaper "$full_path"
    else
        # Fallback: try to find by partial match
        local found=""
        for bname in "${!path_map[@]}"; do
            if [[ "$bname" == "$selected"* ]] || [[ "$selected" == "$bname"* ]]; then
                found="${path_map[$bname]}"
                break
            fi
        done

        if [[ -n "$found" && -f "$found" ]]; then
            apply_wallpaper "$found"
        else
            notify-send "Wallpaper Switcher" "Could not find: $selected" -u critical
            exit 1
        fi
    fi
}

# Get images for --random, --next, --prev
get_images() {
    mapfile -t images < <(find "$WALLDIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | sort)
}

# Command line handling
case "${1:-}" in
    --apply)
        [[ -n "${2:-}" ]] && apply_wallpaper "$2" || echo "Usage: $0 --apply /path/to/image"
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
    --preview)
        generate_preview
        echo "Preview generated: $PREVIEW_OUT"
        ;;
    --current)
        if [[ -L "$CACHE_DIR/current_wallpaper" ]]; then
            readlink -f "$CACHE_DIR/current_wallpaper"
        else
            echo "No wallpaper set"
            exit 1
        fi
        ;;
    --help|-h)
        echo "Wallpaper Switcher"
        echo ""
        echo "Usage: $0 [option]"
        echo ""
        echo "Options:"
        echo "  (none)          Show rofi menu to select wallpaper"
        echo "  --apply <path>  Apply specific wallpaper"
        echo "  --random        Apply random wallpaper"
        echo "  --next          Apply next wallpaper in list"
        echo "  --prev          Apply previous wallpaper in list"
        echo "  --preview       Generate preview for rofi launcher"
        echo "  --current       Print current wallpaper path"
        echo "  --clear-cache   Clear thumbnail cache"
        echo "  --help          Show this help"
        ;;
    *)
        show_menu
        ;;
esac

exit 0
