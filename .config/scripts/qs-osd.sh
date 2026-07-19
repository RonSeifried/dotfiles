#!/bin/bash
# Adjust volume/brightness and notify quickshell OSD

set -u

case "${1:-}" in
    volume-raise)
        wpctl set-mute   @DEFAULT_AUDIO_SINK@ 0
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ -l 1.0
        ;;
    volume-lower)
        wpctl set-mute   @DEFAULT_AUDIO_SINK@ 0
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
        ;;
    volume-mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        ;;
    brightness-raise) brightnessctl set 5%+ -q ;;
    brightness-lower) brightnessctl set 5%- -q ;;
esac

case "${1:-}" in
    volume-*)
        read -r vol mute < <(wpctl get-volume @DEFAULT_AUDIO_SINK@ \
            | awk '{print $2, ($3=="[MUTED]"?"1":"0")}')
        qs ipc call osd volume "$vol" "$mute" 2>/dev/null
        ;;
    brightness-*)
        max=$(brightnessctl max)
        cur=$(brightnessctl get)
        pct=$(awk "BEGIN {printf \"%.2f\", $cur/$max}")
        qs ipc call osd brightness "$pct" 2>/dev/null
        ;;
esac
