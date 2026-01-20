#!/usr/bin/env bash

# Screen Recording Script for Hyprland
# Uses wf-recorder for recording, slurp for area selection
# Saves to file and copies to clipboard

outputDir="$HOME/Videos/screenrecording"
outputFile="recording_$(date +%Y-%m-%d_%H-%M-%S).mp4"
outputPath="$outputDir/$outputFile"
pidFile="/tmp/screenrecord.pid"

mkdir -p "$outputDir"

# Check if a recording is already running
if [[ -f "$pidFile" ]]; then
    pid=$(cat "$pidFile")
    if kill -0 "$pid" 2>/dev/null; then
        # Stop the recording
        kill -SIGINT "$pid"
        rm -f "$pidFile"

        # Wait for the file to be written
        sleep 1

        # Find the most recent recording
        recentFile=$(find "$outputDir" -name 'recording_*.mp4' -printf '%T+ %p\n' | sort -r | head -n 1 | cut -d' ' -f2-)

        if [[ -f "$recentFile" ]]; then
            # Copy to clipboard
            wl-copy < "$recentFile"

            notify-send "Screen Recording" "Recording saved and copied to clipboard." \
                -i video-x-generic \
                -a "Screen Recorder" \
                -t 7000 \
                -u normal \
                --action="scriptAction:-xdg-open $outputDir=Directory" \
                --action="scriptAction:-xdg-open $recentFile=Play"
        fi
        exit 0
    else
        # Stale PID file, remove it
        rm -f "$pidFile"
    fi
fi

# Select area with slurp
geometry=$(slurp 2>/dev/null)

if [[ -z "$geometry" ]]; then
    notify-send "Screen Recording" "Area selection cancelled." \
        -i dialog-error \
        -a "Screen Recorder" \
        -t 3000 \
        -u normal
    exit 1
fi

# Notify that recording has started
notify-send "Screen Recording" "Recording started. Press Shift+Print to stop." \
    -i media-record \
    -a "Screen Recorder" \
    -t 3000 \
    -u normal

# Start recording
wf-recorder -g "$geometry" -f "$outputPath" &
recorderPid=$!
echo "$recorderPid" > "$pidFile"

# Wait for the recorder to finish (will be killed by the stop command)
wait "$recorderPid" 2>/dev/null
