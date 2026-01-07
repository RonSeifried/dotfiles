#!/usr/bin/env bash
# Toggle between different monitor configurations
# Uses hyprdynamicmonitors config or manual hyprctl commands

set -euo pipefail

CONFIG_DIR="$HOME/.config/hyprdynamicmonitors/hyprconfigs"
STATE_FILE="$HOME/.cache/monitor-state"

# Ensure state file exists
mkdir -p "$(dirname "$STATE_FILE")"
touch "$STATE_FILE"

# Get current state (default: "normal")
current_state=$(cat "$STATE_FILE" 2>/dev/null || echo "normal")

# Define monitor configurations
# Adjust these to match your setup
INTERNAL="eDP-1"
EXTERNAL="HDMI-A-1"

toggle_monitors() {
    case "$current_state" in
        "normal")
            # Switch to external only
            hyprctl keyword monitor "$INTERNAL,disable"
            hyprctl keyword monitor "$EXTERNAL,preferred,auto,1"
            echo "external" > "$STATE_FILE"
            notify-send "Monitors" "Switched to external display only"
            ;;
        "external")
            # Switch to internal only
            hyprctl keyword monitor "$EXTERNAL,disable"
            hyprctl keyword monitor "$INTERNAL,preferred,auto,1"
            echo "internal" > "$STATE_FILE"
            notify-send "Monitors" "Switched to internal display only"
            ;;
        "internal")
            # Switch to extended (both)
            hyprctl keyword monitor "$INTERNAL,preferred,0x0,1"
            hyprctl keyword monitor "$EXTERNAL,preferred,auto-right,1"
            echo "extended" > "$STATE_FILE"
            notify-send "Monitors" "Switched to extended display"
            ;;
        "extended")
            # Switch to mirror
            hyprctl keyword monitor "$INTERNAL,1920x1080,0x0,1"
            hyprctl keyword monitor "$EXTERNAL,1920x1080,0x0,1,mirror,$INTERNAL"
            echo "mirror" > "$STATE_FILE"
            notify-send "Monitors" "Switched to mirrored display"
            ;;
        "mirror"|*)
            # Back to normal (both enabled, extended)
            hyprctl keyword monitor "$INTERNAL,preferred,0x0,1"
            hyprctl keyword monitor "$EXTERNAL,preferred,auto-right,1"
            echo "normal" > "$STATE_FILE"
            notify-send "Monitors" "Switched to normal (extended) display"
            ;;
    esac
}

# Check for specific argument
case "${1:-toggle}" in
    "toggle")
        toggle_monitors
        ;;
    "status")
        echo "Current state: $current_state"
        ;;
    "internal")
        hyprctl keyword monitor "$EXTERNAL,disable"
        hyprctl keyword monitor "$INTERNAL,preferred,auto,1"
        echo "internal" > "$STATE_FILE"
        notify-send "Monitors" "Internal display only"
        ;;
    "external")
        hyprctl keyword monitor "$INTERNAL,disable"
        hyprctl keyword monitor "$EXTERNAL,preferred,auto,1"
        echo "external" > "$STATE_FILE"
        notify-send "Monitors" "External display only"
        ;;
    "extend")
        hyprctl keyword monitor "$INTERNAL,preferred,0x0,1"
        hyprctl keyword monitor "$EXTERNAL,preferred,auto-right,1"
        echo "extended" > "$STATE_FILE"
        notify-send "Monitors" "Extended display"
        ;;
    "mirror")
        hyprctl keyword monitor "$INTERNAL,1920x1080,0x0,1"
        hyprctl keyword monitor "$EXTERNAL,1920x1080,0x0,1,mirror,$INTERNAL"
        echo "mirror" > "$STATE_FILE"
        notify-send "Monitors" "Mirrored display"
        ;;
    *)
        echo "Usage: $0 {toggle|status|internal|external|extend|mirror}"
        exit 1
        ;;
esac
