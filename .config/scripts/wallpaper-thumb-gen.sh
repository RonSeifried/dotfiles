#!/usr/bin/env bash
# Generate thumbnail cache for wallpaper picker.
# Usage: wallpaper-thumb-gen.sh <wallpaper-dir>
# Output: TSV "<orig>\t<thumb>" per line, sorted by orig basename.

set -eu

dir="${1:-$HOME/Pictures/wallpaper}"
cache="$HOME/.cache/wallpaper-thumbs"
size="480x320^"
quality=82

mkdir -p "$cache"

# Newline-safe iteration via find -print0
while IFS= read -r -d '' orig; do
    hash=$(printf '%s' "$orig" | sha1sum | cut -c1-16)
    thumb="$cache/$hash.jpg"

    if [ ! -f "$thumb" ] || [ "$orig" -nt "$thumb" ]; then
        magick "$orig" -auto-orient -thumbnail "$size" -gravity center -extent "${size%^}" -quality "$quality" "$thumb" 2>/dev/null || continue
    fi

    printf '%s\t%s\n' "$orig" "$thumb"
done < <(find "$dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print0 | sort -z)
