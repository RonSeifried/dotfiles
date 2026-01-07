#!/usr/bin/env bash
# Project Opener - Opens projects in Zed + Kitty with tmux
set -euo pipefail

# Configuration
DEV_DIR="$HOME/dev"
ROFI_THEME="$HOME/.config/rofi/config.rasi"

# Find projects (2 levels deep in ~/dev)
find_projects() {
    find "$DEV_DIR" -mindepth 2 -maxdepth 2 -type d -printf '%P\n' 2>/dev/null | sort
}

# Get list of projects
projects=$(find_projects)

if [[ -z "$projects" ]]; then
    notify-send "Project Opener" "No projects found in $DEV_DIR" -u normal
    exit 0
fi

# Show rofi menu
chosen=$(printf '%s\n' "$projects" | rofi -dmenu -i -p "Projects" -theme "$ROFI_THEME")

# Exit if nothing chosen
[[ -z "$chosen" ]] && exit 0

# Full path to project
project_dir="$DEV_DIR/$chosen"
project_name=$(basename "$chosen")

if [[ ! -d "$project_dir" ]]; then
    notify-send "Project Opener" "Directory not found: $project_dir" -u critical
    exit 1
fi

# Open in Zed editor
if command -v zeditor &>/dev/null; then
    zeditor "$project_dir" &
elif command -v zed &>/dev/null; then
    zed "$project_dir" &
fi

# Small delay to let editor start
sleep 0.2

# Open kitty with tmux session (attach if exists, create if not)
if command -v kitty &>/dev/null; then
    kitty --detach --directory "$project_dir" \
        tmux new-session -As "$project_name" -c "$project_dir"
else
    notify-send "Project Opener" "Kitty not found" -u critical
    exit 1
fi
