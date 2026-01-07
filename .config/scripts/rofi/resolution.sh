#!/usr/bin/env bash
# Resolution/Display Mode Switcher
# Dynamically detects monitors and offers resolution options

# Get list of connected monitors
get_monitors() {
    hyprctl monitors -j | jq -r '.[].name'
}

# Get primary (first) monitor
get_primary_monitor() {
    hyprctl monitors -j | jq -r '.[0].name'
}

# Get secondary monitor (if exists)
get_secondary_monitor() {
    hyprctl monitors -j | jq -r '.[1].name // empty'
}

# Get available resolutions for a monitor
get_resolutions() {
    local monitor="$1"
    hyprctl monitors -j | jq -r --arg mon "$monitor" '.[] | select(.name == $mon) | .availableModes[]' 2>/dev/null | \
        sed 's/@.*//' | sort -t'x' -k1 -nr | uniq | head -10
}

# Build menu options
build_menu() {
    local primary secondary

    primary=$(get_primary_monitor)
    secondary=$(get_secondary_monitor)

    echo "━━━ Resolution ━━━"

    # Show available resolutions for primary monitor
    while IFS= read -r res; do
        echo "  $res"
    done < <(get_resolutions "$primary")

    echo ""
    echo "󰍹  Preferred (Auto)"

    # If secondary monitor exists, show display modes
    if [[ -n "$secondary" ]]; then
        echo ""
        echo "━━━ Display Mode ━━━"
        echo "  Mirror ($secondary → $primary)"
        echo "  Extend Right"
        echo "  Extend Left"
        echo "󰶐  $secondary Only"
        echo "󰍹  $primary Only"
    fi
}

# Apply resolution
apply_resolution() {
    local choice="$1"
    local primary secondary

    primary=$(get_primary_monitor)
    secondary=$(get_secondary_monitor)

    case "$choice" in
        "󰍹  Preferred (Auto)")
            hyprctl keyword monitor "$primary,preferred,auto,1"
            notify-send "Resolution" "Set $primary to preferred mode" -t 2000
            ;;

        "  Mirror"*)
            if [[ -n "$secondary" ]]; then
                hyprctl keyword monitor "$primary,preferred,0x0,1"
                hyprctl keyword monitor "$secondary,preferred,0x0,1,mirror,$primary"
                notify-send "Display Mode" "Mirroring $secondary to $primary" -t 2000
            fi
            ;;

        "  Extend Right")
            if [[ -n "$secondary" ]]; then
                local primary_width
                primary_width=$(hyprctl monitors -j | jq -r --arg mon "$primary" '.[] | select(.name == $mon) | .width')
                hyprctl keyword monitor "$primary,preferred,0x0,1"
                hyprctl keyword monitor "$secondary,preferred,${primary_width}x0,1"
                notify-send "Display Mode" "$secondary extended to right" -t 2000
            fi
            ;;

        "  Extend Left")
            if [[ -n "$secondary" ]]; then
                local secondary_width
                secondary_width=$(hyprctl monitors -j | jq -r --arg mon "$secondary" '.[] | select(.name == $mon) | .width')
                hyprctl keyword monitor "$secondary,preferred,0x0,1"
                hyprctl keyword monitor "$primary,preferred,${secondary_width}x0,1"
                notify-send "Display Mode" "$secondary extended to left" -t 2000
            fi
            ;;

        "󰶐  $secondary Only")
            hyprctl keyword monitor "$primary,disable"
            hyprctl keyword monitor "$secondary,preferred,0x0,1"
            notify-send "Display Mode" "Using $secondary only" -t 2000
            ;;

        "󰍹  $primary Only")
            if [[ -n "$secondary" ]]; then
                hyprctl keyword monitor "$secondary,disable"
            fi
            hyprctl keyword monitor "$primary,preferred,0x0,1"
            notify-send "Display Mode" "Using $primary only" -t 2000
            ;;

        "  "*)
            # Resolution selected (e.g., "  1920x1080")
            local res="${choice#*  }"
            res="${res// /}"
            hyprctl keyword monitor "$primary,$res,auto,1"
            notify-send "Resolution" "Set $primary to $res" -t 2000
            ;;

        "━━━"* | "")
            # Separator or empty - ignore
            exit 0
            ;;

        *)
            notify-send "Resolution" "Unknown option: $choice" -u critical
            ;;
    esac
}

# Main
MENU=$(build_menu)
CHOICE=$(echo -e "$MENU" | rofi -dmenu -i -p "󰍹 Display" -theme "$HOME/.config/rofi/config.rasi")

[[ -z "$CHOICE" ]] && exit 0

apply_resolution "$CHOICE"
