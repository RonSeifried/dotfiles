#!/usr/bin/env bash
# Read-only health report for the desktop and its generated state.
set -u
repo=${DOTFILES_REPO:-$HOME/dev/personal/dotfiles}
format=${1:-text}
errors=0 warnings=0
issues=()

need() { if ! command -v "$1" >/dev/null 2>&1; then issues+=("Missing command: $1"); errors=$((errors + 1)); fi; }
for cmd in niri qs wallust awww jq grim slurp wl-copy nmcli brightnessctl playerctl \
    fd plocate python3 notify-send xdg-open gpu-screen-recorder upower powerprofilesctl \
    git zstd curl; do need "$cmd"; done

[[ -r "$HOME/.cache/wal/colors.json" ]] || { issues+=("No generated Wallust palette"); warnings=$((warnings + 1)); }
[[ -e "$HOME/.cache/current_wallpaper" ]] || { issues+=("No current wallpaper link"); warnings=$((warnings + 1)); }
if [[ -d "$repo/.git" ]] && [[ -n $(git -C "$repo" status --porcelain 2>/dev/null) ]]; then
    issues+=("Dotfiles contain uncommitted changes"); warnings=$((warnings + 1))
fi
broken=$(find "$repo" -xtype l -print 2>/dev/null | head -n 5)
if [[ -n "$broken" ]]; then issues+=("Broken links detected"); warnings=$((warnings + 1)); fi

if [[ "$format" == "--json" ]]; then
    printf '%s\n' "$(printf '%s\n' "${issues[@]}" | jq -Rsc --argjson errors "$errors" --argjson warnings "$warnings" \
        '{errors:$errors,warnings:$warnings,issues:(split("\n")|map(select(length>0)))}')"
else
    printf 'Desktop health: %d errors, %d warnings\n' "$errors" "$warnings"
    printf ' • %s\n' "${issues[@]}"
fi
(( errors == 0 ))
