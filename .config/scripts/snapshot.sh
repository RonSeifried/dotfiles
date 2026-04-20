#!/usr/bin/env bash

outputDir="$HOME/Pictures/Screenshots/"
outputFile="snapshot_$(date +%Y-%m-%d_%H-%M-%S).png"
outputPath="$outputDir/$outputFile"
mkdir -p "$outputDir"

mode=${1:-area}

case "$mode" in
active|output|area)
    ;;
*)
    echo "Invalid option: $mode"
    echo "Usage: $0 {active|output|area}"
    exit 1
    ;;
esac

do_screenshot() {
    if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
        grimblast copysave "$mode" "$outputPath"
    else
        case "$mode" in
            area)   grim -g "$(slurp)" "$outputPath" ;;
            active) grim -g "$(swaymsg -t get_tree 2>/dev/null | jq -r '.. | select(.focused?) | .rect | "\(.x),\(.y) \(.width)x\(.height)"' 2>/dev/null || slurp)" "$outputPath" ;;
            output) grim "$outputPath" ;;
        esac
        wl-copy < "$outputPath" 2>/dev/null || true
    fi
}

if do_screenshot; then
    recentFile=$(find "$outputDir" -name 'snapshot_*.png' -printf '%T+ %p\n' | sort -r | head -n 1 | cut -d' ' -f2-)
    notify-send "Screenshot" "Saved." \
        -i video-x-generic \
        -t 5000 \
        --action="scriptAction:-xdg-open $outputDir=Directory" \
        --action="scriptAction:-xdg-open $recentFile=View"
fi
