#!/usr/bin/env bash

# Screen recording (compositor-agnostic Wayland; bound in niri keybinds.kdl).
# Uses gpu-screen-recorder, slurp for area selection.
# Toggle: first press starts, second press stops and saves.

set -u

outputDir="$HOME/Videos/screenrecording"
runtimeDir="${XDG_RUNTIME_DIR:-/run/user/$UID}"
lockFile="$runtimeDir/quickshell-screenrecord.pid"

mkdir -p "$outputDir" "$runtimeDir"

recorder_pid=""
cleanup() {
    if [[ -n "$recorder_pid" && -f "$lockFile" ]]; then
        read -r stored_pid _ < "$lockFile" || true
        [[ "$stored_pid" == "$recorder_pid" ]] && rm -f -- "$lockFile"
    fi
    qs ipc call activity end recording >/dev/null 2>&1 || true
}

# --- Stop if already recording ---
if [[ -f "$lockFile" ]]; then
    existing_pid=""; existing_start=""
    read -r existing_pid existing_start < "$lockFile" || true
    existing_exe=""
    current_start=""
    if [[ "$existing_pid" =~ ^[0-9]+$ ]]; then
        existing_exe=$(readlink -f "/proc/$existing_pid/exe" 2>/dev/null || true)
        current_start=$(awk '{print $22}' "/proc/$existing_pid/stat" 2>/dev/null || true)
    fi
    if [[ "${existing_exe##*/}" == "gpu-screen-recorder" \
        && -n "$existing_start" && "$current_start" == "$existing_start" ]]; then
        kill -SIGINT "$existing_pid" 2>/dev/null || true
        qs ipc call activity end recording >/dev/null 2>&1 || true

        sleep 1

        recentFile=$(find "$outputDir" -name 'recording_*.mp4' -printf '%T+ %p\n' \
            | sort -r | head -n 1 | cut -d' ' -f2-)

        if [[ -f "$recentFile" ]]; then
            wl-copy < "$recentFile"
            choice=$(notify-send "Screen Recording" "Saved: $(basename "$recentFile")" \
                -i video-x-generic -a "Screen Recorder" -t 5000 --wait \
                --action=directory=Directory --action=play=Play 2>/dev/null || true)
            case "$choice" in
                directory) xdg-open "$outputDir" >/dev/null 2>&1 & ;;
                play) xdg-open "$recentFile" >/dev/null 2>&1 & ;;
            esac
        fi
        exit 0
    fi
    # Stale/corrupt PID file: remove only our per-user runtime state and allow
    # a new recording to start.
    rm -f -- "$lockFile"
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
# Strip decimals (slurp emits floats at fractional display scales)
_x="${_x%.*}"; _y="${_y%.*}"; _w="${_w%.*}"; _h="${_h%.*}"
region="${_w}x${_h}+${_x}+${_y}"

outputPath="$outputDir/recording_$(date +%Y-%m-%d_%H-%M-%S).mp4"

qs ipc call activity begin recording Recording 󰑋 >/dev/null 2>&1 || true
trap cleanup EXIT INT TERM

notify-send "Screen Recording" "Recording started. Press Shift+Print to stop." \
    -i media-record -a "Screen Recorder" -t 3000

gpu-screen-recorder -w region -region "$region" -c mp4 -f 60 \
    -k h264 -fallback-cpu-encoding yes -o "$outputPath" &
recorder_pid=$!
recorder_start=$(awk '{print $22}' "/proc/$recorder_pid/stat" 2>/dev/null || true)
if [[ -z "$recorder_start" ]]; then
    wait "$recorder_pid"
    exit $?
fi
pid_tmp="$lockFile.$$.tmp"
printf '%s %s\n' "$recorder_pid" "$recorder_start" > "$pid_tmp"
chmod 600 "$pid_tmp"
mv -f -- "$pid_tmp" "$lockFile"
wait "$recorder_pid"
