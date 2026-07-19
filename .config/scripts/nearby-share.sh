#!/usr/bin/env bash
# Thin continuity adapter: prefer LocalSend, then KDE Connect.
set -u
if command -v localsend_app >/dev/null 2>&1; then
    exec localsend_app
elif command -v localsend >/dev/null 2>&1; then
    exec localsend
elif command -v kdeconnect-app >/dev/null 2>&1; then
    exec kdeconnect-app
elif command -v kdeconnect-cli >/dev/null 2>&1; then
    exec kitty --class=floating -e sh -c 'kdeconnect-cli -a; printf "\nUse kdeconnect-cli --share FILE -d DEVICE\n"; read -r'
else
    notify-send -a "Nearby Share" "No continuity provider installed" \
        "Install LocalSend or KDE Connect to share files and clipboard with nearby devices." -i network-wireless
fi
