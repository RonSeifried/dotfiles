#!/bin/bash


hyprctl dispatch togglespecialworkspace drop

# Nur starten, wenn es nicht läuft
if ! pgrep -f "kitty.*taskwarrior-tui" > /dev/null; then
  kitty --class dropterm -e taskwarrior-tui &
  sleep 0.5
  hyprctl dispatch focuswindow "class:dropterm"
fi
