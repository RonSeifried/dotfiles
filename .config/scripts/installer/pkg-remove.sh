#!/bin/bash
INSTALLER_DIR="$(dirname "$(readlink -f "$0")")"

fzf_args=(
  --multi
  --preview 'yay -Qi {1}'
  --preview-label='alt-p: toggle description, alt-j/k: scroll, tab: multi-select, F11: maximize'
  --preview-label-pos='bottom'
  --preview-window 'down:65%:wrap'
  --bind 'alt-p:toggle-preview'
  --bind 'alt-d:preview-half-page-down,alt-u:preview-half-page-up'
  --bind 'alt-k:preview-up,alt-j:preview-down'
  --color 'pointer:red,marker:red'
)

pkg_names=$(yay -Qqe | fzf "${fzf_args[@]}")

if [[ -n "$pkg_names" ]]; then
  mapfile -t pkgs <<< "$pkg_names"
  sudo pacman -Rns --noconfirm "${pkgs[@]}"
  "$INSTALLER_DIR/show-done.sh"
fi
