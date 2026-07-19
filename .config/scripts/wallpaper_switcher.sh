#!/usr/bin/env bash
# Wallpaper Switcher — backend for the Quickshell WallpaperPicker.
# Selection UI lives in qs (.config/quickshell/menus/WallpaperPicker.qml);
# this script handles apply/cycle/random/symlink + wallust regen.

set -u

WALLDIR="${WALLPAPER_DIR:-$HOME/Pictures/wallpaper}"
CACHE_DIR="$HOME/.cache"
THUMB_DIR="$CACHE_DIR/wallpaper-thumbs"
OVERVIEW_WALL="$CACHE_DIR/overview-wallpaper.png"
OVERVIEW_PID="$CACHE_DIR/overview-swaybg.pid"
REFRESH_LOCK="$CACHE_DIR/wallpaper-refresh.lock"
REFRESH_LOG="$CACHE_DIR/wallpaper-refresh.log"
SETTINGS="$HOME/.config/quickshell/settings.json"

mkdir -p "$THUMB_DIR"

update_overview_wallpaper() {
    local selected="$1"
    local overview_tmp="${OVERVIEW_WALL}.tmp.png"
    [[ -f "$selected" ]] || return 1
    command -v magick &>/dev/null || return 0
    command -v swaybg &>/dev/null || return 0

    # The overview is deliberately soft, so retaining an 8K source resolution
    # only wastes time and memory. swaybg scales this lightweight blurred image
    # to the output. Write atomically so it never observes a partial PNG.
    magick "$selected" -filter Gaussian -resize 12.5% -blur 0x6 \
        -modulate 82,82,100 -quality 86 "$overview_tmp" || return 1
    mv -f "$overview_tmp" "$OVERVIEW_WALL"

    [[ "${DEFER_OVERVIEW_LAUNCH:-0}" == "1" ]] || start_overview_backdrop
}

start_overview_backdrop() {
    if [[ -f "$OVERVIEW_PID" ]]; then
        local old_pid
        old_pid=$(<"$OVERVIEW_PID")
        if [[ "$old_pid" =~ ^[0-9]+$ ]] && [[ "$(ps -p "$old_pid" -o comm= 2>/dev/null)" == "swaybg" ]]; then
            kill "$old_pid" 2>/dev/null || true
        fi
    fi
    # Detach from picker/hook IPC lifetimes; otherwise a short-lived caller can
    # take the backdrop process down with its process group.
    # fd 9 may be the palette refresh lock. Never let the persistent backdrop
    # inherit it, otherwise every future wallpaper refresh blocks forever.
    nohup swaybg -o '*' -m fill -i "$OVERVIEW_WALL" \
        >"$CACHE_DIR/overview-swaybg.log" 2>&1 9>&- &
    printf '%s\n' "$!" > "$OVERVIEW_PID"
}

start_overview_preview() {
    local selected="$1" hash thumb preview_tmp
    hash=$(printf '%s' "$selected" | sha1sum | cut -c1-16)
    thumb="$THUMB_DIR/$hash.jpg"
    [[ -f "$thumb" ]] || return 0
    preview_tmp="${OVERVIEW_WALL}.preview.png"
    magick "$thumb" -blur 0x5 -modulate 82,82,100 "$preview_tmp" 2>/dev/null || return 0
    mv -f "$preview_tmp" "$OVERVIEW_WALL"
    start_overview_backdrop
}

# Palette generation, compositor theme hooks and the overview blur are useful,
# but none of them should hold the picker open. Serialize refresh workers and
# discard stale ones so rapid carousel changes always finish on the last image.
refresh_desktop() {
    local requested="$1"
    exec 9>"$REFRESH_LOCK"
    flock 9

    # Resolve the wallpaper that is current *after* waiting for the lock, then
    # compare canonical paths so stale workers exit without rejecting a valid
    # selection merely because it used a symlink or relative spelling.
    local selected requested_real
    selected=$(readlink -f "$CACHE_DIR/current_wallpaper" 2>/dev/null || true)
    requested_real=$(readlink -f "$requested" 2>/dev/null || true)
    [[ -n "$selected" && -f "$selected" ]] || return 1
    # A newer carousel selection superseded this queued worker. Canonicalize
    # both paths so symlink/relative spelling differences never reject a valid
    # request, then leave the expensive work to the newest worker.
    [[ "$requested_real" == "$selected" ]] || return 0

    DEFER_OVERVIEW_LAUNCH=1 update_overview_wallpaper "$selected" &
    local overview_job=$!
    if command -v wallust &>/dev/null; then
        wallust run -q "$selected"
    fi
    "$HOME/.config/scripts/wallpaper-analyze.sh" "$selected" >/dev/null 2>&1 || true
    wait "$overview_job" 2>/dev/null || true

    # Release the serialization lock before starting any persistent process.
    # A daemon must never be able to inherit and retain this descriptor.
    flock -u 9
    exec 9>&-
    start_overview_backdrop
    command -v pywalfox &>/dev/null && pywalfox update >/dev/null 2>&1 || true
}

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
        transition=grow; duration=0.7
        if [[ -r "$SETTINGS" ]] && command -v jq &>/dev/null; then
            transition=$(jq -r '.wallpaper.transition // "grow"' "$SETTINGS" 2>/dev/null || echo grow)
            duration=$(jq -r '.wallpaper.duration // 0.7' "$SETTINGS" 2>/dev/null || echo 0.7)
        fi
        awww img "$selected" --transition-type "$transition" --transition-duration "$duration" --transition-pos center
    else
        # swaybg is reserved for Niri's overview backdrop: it has a fixed
        # `wallpaper` namespace, so using a second instance as the normal
        # wallpaper would place both surfaces inside the overview layer rule.
        notify-send "Wallpaper Switcher" "awww is required for the desktop wallpaper" -u critical
        return 1
    fi

    ln -sf "$selected" "$CACHE_DIR/current_wallpaper"
    # The picker already has a cached thumbnail. Use it for an immediate
    # overview backdrop, then let the refresh worker replace it with the
    # higher-quality 960x540 derivative a few seconds later.
    start_overview_preview "$selected"
    # Detach the expensive palette/overview work. The wallpaper itself is now
    # visible and the picker can close immediately (normally well under 1 s).
    nohup "$0" --refresh "$selected" >"$REFRESH_LOG" 2>&1 &

    if [[ "$quiet" != "1" ]]; then
        notify-send "Wallpaper" "Applied: $(basename "$selected")" -t 3000
    fi
}

get_images() {
    mapfile -t images < <(find "$WALLDIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | sort)
}

case "${1:-}" in
    --refresh)
        [[ -n "${2:-}" ]] && refresh_desktop "$2"
        ;;
    --overview)
        selected="${2:-$(readlink -f "$CACHE_DIR/current_wallpaper" 2>/dev/null || true)}"
        if [[ -n "$selected" ]]; then
            update_overview_wallpaper "$selected"
            "$HOME/.config/scripts/wallpaper-analyze.sh" "$selected" >/dev/null 2>&1 || true
        fi
        ;;
    --apply)
        if [[ "${3:-}" == "--notify" ]]; then
            QUIET_APPLY=0
        else
            QUIET_APPLY="${QUIET_APPLY:-1}"
        fi
        if [[ -z "${2:-}" ]]; then
            echo "Usage: $0 --apply /path/to/image"
            exit 1
        fi
        apply_wallpaper "$2"
        ;;
    --random)
        get_images
        [[ ${#images[@]} -gt 0 ]] && apply_wallpaper "${images[$RANDOM % ${#images[@]}]}"
        ;;
    --next|--prev)
        get_images
        if [[ ${#images[@]} -eq 0 ]]; then
            notify-send "Wallpaper Switcher" "No wallpapers found in $WALLDIR" -u critical
            exit 1
        fi
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
        echo "  --overview      Regenerate the blurred Niri overview backdrop"
        echo "  --clear-cache   Clear thumbnail cache"
        echo "  --help          Show this help"
        ;;
    *)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
esac

exit 0
