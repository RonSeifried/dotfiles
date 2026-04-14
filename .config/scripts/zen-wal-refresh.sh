#!/usr/bin/env bash
# ~/.local/bin/zen-wal-refresh.sh
wal -R
pywalfox update 2>/dev/null || true
target="$HOME/.zen/profiles/default/chrome"
[ -d "$target" ] || target=$(ls -d ~/.mozilla/firefox/*default*/chrome 2>/dev/null | head -n1)
[ -n "$target" ] && cp ~/.cache/wal/colors.css "$target/colors.css"
