#!/usr/bin/env bash
# Self-contained Niri dropdown: launch, focus, then close when invoked while
# already focused. This replaces the undeclared external `ndrop` dependency.
set -u

windows=$(niri msg --json windows 2>/dev/null || printf '[]')
id=$(jq -r '[.[] | select(.app_id == "dropdown-terminal")][0].id // empty' <<<"$windows")
focused=$(jq -r '[.[] | select(.app_id == "dropdown-terminal")][0].is_focused // false' <<<"$windows")

if [[ -n "$id" && "$focused" == "true" ]]; then
    exec niri msg action close-window --id "$id"
elif [[ -n "$id" ]]; then
    exec niri msg action focus-window --id "$id"
else
    exec kitty --class dropdown-terminal
fi
