#!/usr/bin/env bash
# Power profile switcher via rofi
# Called from: Waybar battery on-click

THEME="$HOME/.config/rofi/utility.rasi"

ICON_PERF="󱐌"
ICON_BAL="󰾅"
ICON_SAVER="󰾆"

profile_icon() {
    case "$1" in
        performance) printf '%s' "$ICON_PERF" ;;
        balanced)    printf '%s' "$ICON_BAL"  ;;
        power-saver) printf '%s' "$ICON_SAVER" ;;
        *)           printf '󰁹' ;;
    esac
}

current=$(powerprofilesctl get 2>/dev/null)

items=()
for p in performance balanced power-saver; do
    icon=$(profile_icon "$p")
    if [[ "$p" == "$current" ]]; then
        items+=("$icon  $p  ✓")
    else
        items+=("$icon  $p")
    fi
done

chosen=$(printf '%s\n' "${items[@]}" \
    | rofi -dmenu -i -p "󰁹  Power Profile" -theme "$THEME") || exit 0

[[ -z "$chosen" ]] && exit 0

# Extract profile name (second word)
profile=$(printf '%s' "$chosen" | awk '{print $2}')
[[ -z "$profile" ]] && exit 0

if powerprofilesctl set "$profile" 2>/dev/null; then
    notify-send "Power Profile" "Switched to $profile" -t 2500
else
    notify-send "Power Profile" "Failed to set $profile" -u critical
fi
