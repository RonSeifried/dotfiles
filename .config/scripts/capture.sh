#!/usr/bin/env bash
# Capture hub: save + clipboard + history, then offer edit/OCR/reveal actions.
set -eu

mode=${1:-area}
dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
file="$dir/Screenshot from $(date '+%Y-%m-%d %H-%M-%S').png"

case "$mode" in
    area)
        geometry=$(slurp 2>/dev/null || true)
        [[ -n "$geometry" ]] || exit 0
        grim -g "$geometry" "$file"
        ;;
    screen) grim "$file" ;;
    *) printf 'usage: %s area|screen\n' "$0" >&2; exit 2 ;;
esac

wl-copy < "$file"
qs ipc call activity begin capture "Screenshot saved" 󰹑 >/dev/null 2>&1 || true
qs ipc call activity end capture >/dev/null 2>&1 || true

actions=(--action=open=Open --action=reveal=Reveal)
command -v satty >/dev/null 2>&1 && actions+=(--action=edit=Annotate)
command -v tesseract >/dev/null 2>&1 && actions+=(--action=ocr="Copy Text")
choice=$(notify-send -a "Screenshot" -i "$file" "Screenshot captured" \
    "Copied to the clipboard" "${actions[@]}" --wait 2>/dev/null || true)
case "$choice" in
    open) xdg-open "$file" ;;
    reveal) xdg-open "$dir" ;;
    edit)
        # Satty keeps the original as its default output; saving replaces it
        # intentionally and the final image is copied again afterwards.
        satty --filename "$file" --output-filename "$file" || true
        [[ -f "$file" ]] && wl-copy < "$file"
        ;;
    ocr) tesseract "$file" stdout 2>/dev/null | wl-copy ;;
esac
