#!/usr/bin/env bash
# install.sh — bootstrap this niri/Quickshell setup on a fresh Arch machine.
#
# Run from anywhere the repo is cloned:
#     git clone <repo> ~/dev/personal/rshell   # (or any path)
#     cd ~/dev/personal/rshell
#     ./install.sh
#
# It installs dependencies, then symlinks the configs into ~/.config so they
# are found regardless of where the repo lives. No GNU Stow required — the
# repo is NOT tied to ~/dotfiles.
#
# Machine-specific config (monitor outputs) is NOT tracked: it lives in
# .config/niri/includes/host.kdl, seeded from host.kdl.example on first run.
# Generated/dynamic files (wallust palette output) and sensitive files
# (API keys) are gitignored and never linked from the repo.

set -euo pipefail

# ── Repo root = directory of this script (location-independent) ──────────────
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$REPO_DIR/.config"
CONFIG_DST="${XDG_CONFIG_HOME:-$HOME/.config}"

# ── Tiny output helpers ──────────────────────────────────────────────────────
c_blue='\033[1;34m'; c_green='\033[1;32m'; c_yellow='\033[1;33m'; c_red='\033[1;31m'; c_reset='\033[0m'
info()  { printf "${c_blue}::${c_reset} %s\n" "$*"; }
ok()    { printf "${c_green}  ✓${c_reset} %s\n" "$*"; }
warn()  { printf "${c_yellow}  !${c_reset} %s\n" "$*"; }
err()   { printf "${c_red}  ✗${c_reset} %s\n" "$*" >&2; }
ask()   { local q="$1" a; read -rp "$(printf "${c_yellow}?${c_reset} %s [y/N] " "$q")" a; [[ "${a,,}" == y* ]]; }

# Read a package-list file: strip comments (incl. trailing) and blank lines.
read_list() { sed -E 's/#.*$//; s/[[:space:]]+$//' "$1" | grep -vE '^[[:space:]]*$' || true; }

# ── 0. Sanity ────────────────────────────────────────────────────────────────
if ! command -v pacman &>/dev/null; then
    err "pacman not found — this setup targets Arch Linux. Aborting."
    exit 1
fi

# ── 1. Dependencies ──────────────────────────────────────────────────────────
install_deps() {
    info "Installing pacman packages…"
    mapfile -t pac < <(read_list "$REPO_DIR/packages/pacman.txt")
    sudo pacman -S --needed --noconfirm "${pac[@]}"
    ok "pacman packages installed"

    if ! command -v yay &>/dev/null; then
        warn "yay not found — bootstrapping it from the AUR"
        local tmp; tmp="$(mktemp -d)"
        sudo pacman -S --needed --noconfirm git base-devel
        git clone https://aur.archlinux.org/yay.git "$tmp/yay"
        ( cd "$tmp/yay" && makepkg -si --noconfirm )
        rm -rf "$tmp"
        ok "yay installed"
    fi

    info "Installing AUR packages…"
    mapfile -t aur < <(read_list "$REPO_DIR/packages/aur.txt")
    yay -S --needed --noconfirm "${aur[@]}"
    ok "AUR packages installed"

    install_omz_plugins
}

install_omz_plugins() {
    local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    [[ -d "$HOME/.oh-my-zsh" ]] || { warn "Oh My Zsh not present yet — skipping plugin clones (re-run after first zsh login)"; return; }
    info "Installing Oh My Zsh custom plugins…"
    while read -r url name; do
        [[ -z "$url" ]] && continue
        local dest="$zsh_custom/plugins/$name"
        if [[ -d "$dest" ]]; then ok "$name already present"; else
            git clone --depth=1 "$url" "$dest" && ok "$name"
        fi
    done < <(read_list "$REPO_DIR/packages/omz-plugins.txt")
}

# ── 2. Link configs into $HOME via stow (per-file, location-free) ────────────
# Uses GNU stow under the hood so the repo can live at any path. Per-file
# symlinks (--no-folding) mean machine-local / generated files inside shared
# dirs (zed/settings.json, ~/.config/wal, …) coexist untouched. What gets
# linked is controlled by .stow-local-ignore (repo tooling/docs excluded).
link_configs() {
    if ! command -v stow &>/dev/null; then
        info "Installing stow (required for linking)…"
        sudo pacman -S --needed --noconfirm stow
    fi
    info "Linking dotfiles into \$HOME via stow…"
    # --no-folding: always per-file symlinks (never whole-dir), so unmanaged
    #   local files in a shared dir are never displaced.
    # --restow: idempotent — unstow stale links then re-link. Safe to re-run.
    ( cd "$REPO_DIR" && stow --no-folding --restow --target="$HOME" --verbose=1 . )
    ok "configs linked"
}

# ── 3. Seed machine-local config ─────────────────────────────────────────────
seed_host_config() {
    local host="$CONFIG_SRC/niri/includes/host.kdl"
    local example="$CONFIG_SRC/niri/includes/host.kdl.example"
    if [[ -f "$host" ]]; then
        ok "niri host.kdl already present (machine-local, untracked)"
    elif [[ -f "$example" ]]; then
        cp "$example" "$host"
        warn "seeded niri host.kdl from example — EDIT IT with this machine's monitor outputs:"
        warn "  $host"
    fi
}

# ── 4. System bits (optional, need sudo) ─────────────────────────────────────
post_setup() {
    info "Optional system setup"

    if [[ -d "$REPO_DIR/system/udev" ]] && ask "Install udev rules from system/udev/ to /etc/udev/rules.d?"; then
        sudo cp "$REPO_DIR"/system/udev/*.rules /etc/udev/rules.d/ && ok "udev rules installed"
    fi

    if ask "Enable NetworkManager + bluetooth services?"; then
        sudo systemctl enable --now NetworkManager.service bluetooth.service && ok "services enabled"
    fi

    if [[ "${SHELL:-}" != *zsh ]] && ask "Set zsh as your default shell?"; then
        chsh -s "$(command -v zsh)" && ok "default shell set to zsh (re-login to apply)"
    fi
}

# ── Done ─────────────────────────────────────────────────────────────────────
final_notes() {
    cat <<EOF

$(printf "${c_green}Done.${c_reset}") Remaining manual steps:

  1. Set a wallpaper + generate colors:
       wallust run /path/to/wallpaper.jpg
     (themes niri borders, Quickshell, kitty, starship, yazi)

  2. Edit machine-local monitor outputs:
       $CONFIG_SRC/niri/includes/host.kdl

  3. (optional) Lock-screen face icon:
       cp your-photo.jpg ~/.face.icon

  Log out / back in to start a niri session.
EOF
}

main() {
    info "Bootstrapping from: $REPO_DIR"
    if ask "Install dependencies (pacman + AUR + omz plugins)?"; then install_deps; else warn "skipping dependency install"; fi
    seed_host_config
    link_configs
    post_setup
    final_notes
}

main "$@"
