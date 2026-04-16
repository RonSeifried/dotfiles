#!/usr/bin/env bash

# Screen Recording Script for Hyprland
# Uses gpu-screen-recorder, slurp for area selection
# Toggle: first press starts, second press stops and saves

outputDir="$HOME/Videos/screenrecording"
lockFile="/tmp/screenrecord.lock"

mkdir -p "$outputDir"

# --- Stop if already recording ---
if [[ -f "$lockFile" ]]; then
    pkill -SIGINT -f "gpu-screen-recorder" 2>/dev/null
    rm -f "$lockFile"

    sleep 1

    recentFile=$(find "$outputDir" -name 'recording_*.mp4' -printf '%T+ %p\n' \
        | sort -r | head -n 1 | cut -d' ' -f2-)

    if [[ -f "$recentFile" ]]; then
        wl-copy < "$recentFile"
        notify-send "Screen Recording" "Saved: $(basename "$recentFile")" \
            -i video-x-generic -a "Screen Recorder" -t 5000 \
            --action="scriptAction:-xdg-open $outputDir=Directory" \
            --action="scriptAction:-xdg-open $recentFile=Play"
    fi
    exit 0
fi

# --- Start new recording ---
geometry=$(slurp 2>/dev/null)
if [[ -z "$geometry" ]]; then
    notify-send "Screen Recording" "Cancelled." \
        -i dialog-error -a "Screen Recorder" -t 3000
    exit 1
fi

# Convert slurp "X,Y WxH" → "WxH+X+Y"
_pos="${geometry% *}"
_size="${geometry#* }"
_x="${_pos%,*}"; _y="${_pos#*,}"
_w="${_size%x*}"; _h="${_size#*x}"
region="${_w}x${_h}+${_x}+${_y}"

outputPath="$outputDir/recording_$(date +%Y-%m-%d_%H-%M-%S).mp4"

touch "$lockFile"

notify-send "Screen Recording" "Recording started. Press Shift+Print to stop." \
    -i media-record -a "Screen Recorder" -t 3000

gpu-screen-recorder -w region -region "$region" -c mp4 -f 60 -o "$outputPath"

rm -f "$lockFile"
