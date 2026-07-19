#!/usr/bin/env bash
# Derive material guidance from a tiny image sample.  The cache key makes
# revisiting a wallpaper effectively free.
set -eu

image=${1:?wallpaper path required}
cache_dir="$HOME/.cache/wallpaper-analysis"
output="$HOME/.cache/wal/wallpaper-analysis.json"
mkdir -p "$cache_dir" "${output%/*}"
key=$(printf '%s:%s:%s' "$image" "$(stat -c %s "$image")" "$(stat -c %Y "$image")" | sha256sum | cut -c1-20)
cached="$cache_dir/$key.json"

if [[ ! -f "$cached" ]]; then
    # 64 px is enough to distinguish a bright/busy photograph from a quiet
    # dark wallpaper without decoding and filtering at display resolution.
    stats=$(magick "$image" -auto-orient -resize '64x64!' -colorspace sRGB \
        -format '%[fx:(mean.r+mean.g+mean.b)/3],%[fx:(standard_deviation.r+standard_deviation.g+standard_deviation.b)/3]' info:)
    luminance=${stats%,*}
    complexity=${stats#*,}
    density=$(awk -v l="$luminance" -v c="$complexity" 'BEGIN {
        d = 0.88 + l * 0.10 + c * 0.28; if (d < 0.88) d=0.88; if (d > 1.08) d=1.08;
        printf "%.4f", d
    }')
    jq -n --arg source "$image" --argjson luminance "$luminance" \
        --argjson complexity "$complexity" --argjson density "$density" \
        '{schemaVersion:1, source:$source, luminance:$luminance, complexity:$complexity, density:$density}' > "$cached.tmp"
    mv -f "$cached.tmp" "$cached"
fi
cp -f "$cached" "$output.tmp"
mv -f "$output.tmp" "$output"
