# ~/.local/bin/zen-wal-refresh.sh
#!/usr/bin/env bash
wal -R
pywalfox update 2>/dev/null || true
target="$HOME/.zen/profiles/default/chrome"
[ -d "$target" ] || target=$(ls -d ~/.mozilla/firefox/*default*/chrome 2>/dev/null | head -n1)
[ -n "$target" ] && cp ~/.cache/wal/colors.css "$target/colors.css"
