#!/bin/bash

browser=$(xdg-settings get default-web-browser)

case $browser in
google-chrome* | brave-browser* | microsoft-edge* | opera* | vivaldi* | zen*) ;;
*) browser="chromium.desktop" ;;
esac

browser_exec=$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' {~/.local,~/.nix-profile,/usr}/share/applications/$browser 2>/dev/null | head -1)

if [[ -z "$browser_exec" ]]; then
    for fallback in google-chrome chromium brave zen-browser firefox; do
        if command -v "$fallback" &>/dev/null; then
            browser_exec="$fallback"
            break
        fi
    done
fi

# Firefox and Zen do not support --app
if [[ "$browser_exec" == *"firefox"* ]] || [[ "$browser_exec" == *"zen"* ]]; then
    exec "$browser_exec" --new-window "$1" "${@:2}" &
else
    exec "$browser_exec" --app="$1" "${@:2}" &
fi
