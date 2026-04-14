#!/usr/bin/env bash
# Unified Dropdown Terminal - Toggle special workspace with any app
# Usage: dropdown.sh [app] [args...]
#   dropdown.sh yazi           - File manager
#   dropdown.sh taskwarrior    - Task manager
#   dropdown.sh btop           - System monitor
#   dropdown.sh                - Plain terminal

set -euo pipefail

# Configuration
WORKSPACE="drop"
TERM_CLASS="dropterm"
TERMINAL="kitty"

# Parse arguments
APP="${1:-}"
shift 2>/dev/null || true
APP_ARGS="$*"

# Determine what to run
case "$APP" in
    yazi|y)
        RUN_CMD="yazi"
        PROCESS_MATCH="yazi"
        ;;
    taskwarrior|task|t)
        RUN_CMD="taskwarrior-tui"
        PROCESS_MATCH="taskwarrior-tui"
        ;;
    btop|b)
        RUN_CMD="btop"
        PROCESS_MATCH="btop"
        ;;
    nvim|n)
        RUN_CMD="nvim $APP_ARGS"
        PROCESS_MATCH="nvim"
        ;;
    "")
        # Plain terminal with tmux
        SESSION_NAME="${PWD##*/}"
        RUN_CMD="tmux new-session -A -s \"$SESSION_NAME\""
        PROCESS_MATCH="tmux"
        ;;
    *)
        # Custom command
        RUN_CMD="$APP $APP_ARGS"
        PROCESS_MATCH="$APP"
        ;;
esac

# Toggle the special workspace
hyprctl dispatch togglespecialworkspace "$WORKSPACE"

# Check if the app is already running in dropterm
if ! pgrep -f "^$TERMINAL.*$PROCESS_MATCH" >/dev/null 2>&1; then
    # Launch the terminal with the app
    $TERMINAL --class "$TERM_CLASS" -e bash -c "$RUN_CMD" &

    # Wait a moment for window to appear
    sleep 0.2

    # Focus the dropdown window
    hyprctl dispatch focuswindow "class:$TERM_CLASS"
fi

exit 0
