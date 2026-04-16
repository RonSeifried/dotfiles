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

# Build run command as array for safe execution
case "$APP" in
    yazi|y)
        RUN_ARGS=(yazi)
        PROCESS_MATCH="yazi"
        ;;
    taskwarrior|task|t)
        RUN_ARGS=(taskwarrior-tui)
        PROCESS_MATCH="taskwarrior-tui"
        ;;
    btop|b)
        RUN_ARGS=(btop)
        PROCESS_MATCH="btop"
        ;;
    nvim|n)
        RUN_ARGS=(nvim "$@")
        PROCESS_MATCH="nvim"
        ;;
    "")
        # Plain terminal with tmux
        SESSION_NAME="${PWD##*/}"
        RUN_ARGS=(tmux new-session -A -s "$SESSION_NAME")
        PROCESS_MATCH="tmux"
        ;;
    *)
        # Custom command
        RUN_ARGS=("$APP" "$@")
        PROCESS_MATCH="$APP"
        ;;
esac

# Check if a dropterm window already exists
HAS_WINDOW=$(hyprctl clients -j 2>/dev/null | python3 -c \
    "import json,sys; c=json.load(sys.stdin); print('yes' if any(x.get('class')=='$TERM_CLASS' for x in c) else 'no')" \
    2>/dev/null || echo "no")

# Toggle the special workspace
hyprctl dispatch togglespecialworkspace "$WORKSPACE"

if [[ "$HAS_WINDOW" == "no" ]]; then
    # Launch the terminal with the app
    "$TERMINAL" --class "$TERM_CLASS" -e "${RUN_ARGS[@]}" &

    # Wait for window to appear then focus
    sleep 0.4
    hyprctl dispatch focuswindow "class:$TERM_CLASS"
fi

exit 0
