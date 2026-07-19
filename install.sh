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

ASSUME_YES=0
CHECK_ONLY=0
INSTALL_OPTIONAL="ask"
for arg in "$@"; do
    case "$arg" in
        -y|--yes) ASSUME_YES=1 ;;
        --check) CHECK_ONLY=1 ;;
        --minimal|--no-optional) INSTALL_OPTIONAL=0 ;;
        -h|--help)
            printf 'Usage: %s [--yes] [--minimal] [--check]\n' "$0"
            printf '  --yes       accept onboarding prompts (including optional apps)\n'
            printf '  --minimal   install the complete desktop core, skip personal apps\n'
            printf '  --check     run the portability/health checks without changing anything\n'
            exit 0
            ;;
        *) printf 'Unknown option: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

# ── Repo root = directory of this script (location-independent) ──────────────
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$REPO_DIR/.config"
# The repository tree is rooted at .config and runtime scripts intentionally
# resolve ~/.config. Keep one canonical destination instead of partially
# honoring an alternate XDG_CONFIG_HOME for only the onboarding files.
CONFIG_DST="$HOME/.config"

# ── Tiny output helpers ──────────────────────────────────────────────────────
c_blue='\033[1;34m'; c_green='\033[1;32m'; c_yellow='\033[1;33m'; c_red='\033[1;31m'; c_reset='\033[0m'
info()  { printf "${c_blue}::${c_reset} %s\n" "$*"; }
ok()    { printf "${c_green}  ✓${c_reset} %s\n" "$*"; }
warn()  { printf "${c_yellow}  !${c_reset} %s\n" "$*"; }
err()   { printf "${c_red}  ✗${c_reset} %s\n" "$*" >&2; }
ask()   {
    local q="$1" a
    (( ASSUME_YES )) && return 0
    read -rp "$(printf "${c_yellow}?${c_reset} %s [y/N] " "$q")" a
    [[ "${a,,}" == y* ]]
}

# Read a package-list file: strip comments (incl. trailing) and blank lines.
read_list() { sed -E 's/#.*$//; s/[[:space:]]+$//' "$1" | grep -vE '^[[:space:]]*$' || true; }

# ── 0. Sanity ────────────────────────────────────────────────────────────────
preflight() {
    info "Preflight"
    [[ $EUID -ne 0 ]] || { err "Run as your normal user, not root (sudo is requested when needed)."; return 1; }
    command -v pacman &>/dev/null || { err "pacman not found — this setup targets Arch Linux."; return 1; }
    if (( ! CHECK_ONLY )); then
        [[ -w "$HOME" ]] || { err "HOME is not writable: $HOME"; return 1; }
    fi
    [[ -d "$REPO_DIR/.git" ]] || warn "repository has no .git directory; backups cannot create a Git bundle"
    command -v sudo &>/dev/null || { err "sudo is required for package and service setup"; return 1; }
    ok "Arch user environment looks usable"
}

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
    local zsh_custom="${ZSH_CUSTOM:-$HOME/.config/oh-my-zsh/custom}"
    [[ -r /usr/share/oh-my-zsh/oh-my-zsh.sh ]] || { err "oh-my-zsh package did not provide /usr/share/oh-my-zsh"; return 1; }
    mkdir -p "$zsh_custom/plugins"
    info "Installing Oh My Zsh custom plugins…"
    while read -r url name; do
        [[ -z "$url" ]] && continue
        local dest="$zsh_custom/plugins/$name"
        if [[ -d "$dest" ]]; then ok "$name already present"; else
            git clone --depth=1 "$url" "$dest" && ok "$name"
        fi
    done < <(read_list "$REPO_DIR/packages/omz-plugins.txt")
}

# Optional personal apps (browser, editor, office, TUIs) — NOT shell deps.
install_optional() {
    local list="$REPO_DIR/packages/optional.txt"
    [[ -f "$list" ]] || return
    if ! command -v yay &>/dev/null; then warn "yay missing — skipping optional apps"; return; fi
    info "Installing optional apps…"
    mapfile -t opt < <(read_list "$list")
    [[ ${#opt[@]} -eq 0 ]] && { ok "no optional apps listed"; return; }
    yay -S --needed --noconfirm "${opt[@]}"
    ok "optional apps installed"
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
    info "Checking existing home configuration…"
    local simulation conflict_backup stamp rel
    if ! simulation=$(cd "$REPO_DIR" && stow --no-folding --restow --simulate --target="$HOME" . 2>&1); then
        printf '%s\n' "$simulation"
        mapfile -t conflicts < <(sed -nE \
            's/^  \* existing target is not owned by stow: (.*)$/\1/p; s/^  \* existing target is neither a link nor a directory: (.*)$/\1/p; s#^  \* cannot stow .* over existing target (.*) since .*#\1#p' \
            <<<"$simulation")
        if (( ${#conflicts[@]} == 0 )); then
            err "Stow preflight failed; no files were changed."
            return 1
        fi
        warn "${#conflicts[@]} existing files conflict with this setup."
        ask "Move only those conflicting files into a timestamped recovery folder?" \
            || { err "Cannot continue without resolving Stow conflicts."; return 1; }
        stamp=$(date '+%Y-%m-%d_%H-%M-%S')
        conflict_backup="$HOME/.local/state/dotfiles/preinstall-$stamp"
        for rel in "${conflicts[@]}"; do
            [[ "$rel" != /* && "$rel" != *".."* ]] || { err "Unsafe conflict path: $rel"; return 1; }
            mkdir -p "$conflict_backup/$(dirname "$rel")"
            mv -- "$HOME/$rel" "$conflict_backup/$rel"
        done
        ok "previous files preserved in $conflict_backup"
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
    local host="$CONFIG_DST/niri/includes/host.kdl"
    local example="$CONFIG_SRC/niri/includes/host.kdl.example"
    mkdir -p "$(dirname "$host")"
    if [[ -f "$host" ]]; then
        ok "niri host.kdl already present (machine-local, untracked)"
    elif [[ -f "$example" ]]; then
        printf '%s\n' '// Machine-local output overrides. Empty is safe; see host.kdl.example.' > "$host"
        ok "created safe machine-local Niri override (automatic output defaults)"
    fi

    # kanshi monitor profiles are per-machine too (same pattern as host.kdl).
    local kanshi="$CONFIG_DST/kanshi/config"
    local kanshi_example="$CONFIG_SRC/kanshi/config.example"
    mkdir -p "$(dirname "$kanshi")"
    if [[ -f "$kanshi" ]]; then
        ok "kanshi config already present (machine-local, untracked)"
    elif [[ -f "$kanshi_example" ]]; then
        printf '%s\n' '# Machine-local profiles. Safe default; see config.example for dock profiles.' \
            'profile fallback {' '}' > "$kanshi"
        ok "created safe Kanshi fallback profile"
    fi
}

seed_personal_config() {
    mkdir -p "$CONFIG_DST/zed"
    if [[ ! -e "$CONFIG_DST/zed/settings.json" && -r "$CONFIG_SRC/zed/settings.json.example" ]]; then
        cp "$CONFIG_SRC/zed/settings.json.example" "$CONFIG_DST/zed/settings.json"
        ok "seeded Zed settings without credentials"
    fi

    if [[ ! -e "$HOME/.askai-env" && $ASSUME_YES -eq 0 ]] \
        && ask "Configure the optional Gemini launcher integration now?"; then
        local gemini_key
        read -rsp "Gemini API key: " gemini_key; printf '\n'
        install -m 600 /dev/null "$HOME/.askai-env"
        printf 'export GEMINI_API_KEY=%q\n' "$gemini_key" > "$HOME/.askai-env"
        unset gemini_key
        ok "stored AI credential in ~/.askai-env (mode 600, untracked)"
    fi
}

initialize_wallpaper() {
    local wall_dir="$HOME/Pictures/wallpaper" selected=""
    mkdir -p "$wall_dir"
    if [[ -t 0 && $ASSUME_YES -eq 0 ]]; then
        read -rp "$(printf "${c_yellow}?${c_reset} Wallpaper path (blank = generated neutral default): ")" selected
        selected=${selected/#\~/$HOME}
    fi
    if [[ -z "$selected" ]]; then
        selected=$(find "$wall_dir" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -print -quit 2>/dev/null || true)
    fi
    if [[ -z "$selected" ]]; then
        selected="$wall_dir/dotfiles-default.png"
        # Salience needs several meaningful colour regions; a two-colour
        # gradient can make current wallust builds panic. This produces a
        # subdued, blue-tinted organic fallback with a useful full palette.
        magick -size 2560x1440 plasma:fractal -colorspace sRGB \
            -fill '#13213a' -colorize 40% -modulate 70,85,100 "$selected"
        ok "generated a neutral first-run wallpaper"
    elif [[ ! -f "$selected" ]]; then
        warn "wallpaper not found: $selected; generating the safe default instead"
        selected="$wall_dir/dotfiles-default.png"
        magick -size 2560x1440 plasma:fractal -colorspace sRGB \
            -fill '#13213a' -colorize 40% -modulate 70,85,100 "$selected"
    fi
    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        "$CONFIG_DST/scripts/wallpaper_switcher.sh" --apply "$selected"
    else
        mkdir -p "$HOME/.cache/wal"
        ln -sfn "$selected" "$HOME/.cache/current_wallpaper"
        wallust run -q "$selected"
        "$CONFIG_DST/scripts/wallpaper-analyze.sh" "$selected"
        magick "$selected" -filter Gaussian -resize 12.5% -blur 0x6 \
            -modulate 82,82,100 -quality 86 "$HOME/.cache/overview-wallpaper.png"
    fi
    ok "initialized wallpaper, palette, overview and adaptive material"
}

# ── 4. System bits (optional, need sudo) ─────────────────────────────────────
post_setup() {
    info "Optional system setup"

    if compgen -G '/sys/class/power_supply/BAT*/charge_control_end_threshold' >/dev/null \
        && [[ -d "$REPO_DIR/system/udev" ]] \
        && ask "Install this laptop's battery-threshold udev rule?"; then
        sudo cp "$REPO_DIR"/system/udev/*.rules /etc/udev/rules.d/ && ok "udev rules installed"
    fi

    if ask "Enable NetworkManager, Bluetooth and power profiles?"; then
        sudo systemctl enable --now NetworkManager.service bluetooth.service power-profiles-daemon.service \
            && ok "hardware services enabled"
    fi

    if command -v docker >/dev/null 2>&1 && ask "Enable Docker for the MCP manager?"; then
        sudo systemctl enable --now docker.service
        sudo usermod -aG docker "$USER"
        ok "Docker enabled (group membership applies after re-login)"
    fi

    if ask "Enable the weekly dotfiles backup timer?"; then
        systemctl --user daemon-reload
        systemctl --user enable --now dotfiles-backup.timer && ok "weekly dotfiles backup enabled"
    fi

    # Arch ships this timer as a static unit, normally pulled in automatically.
    # Static units have no [Install] section and must never be passed to
    # `systemctl enable`. Start it only when the package has not activated it.
    if systemctl list-unit-files plocate-updatedb.timer >/dev/null 2>&1; then
        if systemctl is-active --quiet plocate-updatedb.timer; then
            ok "daily Spotlight index timer already active"
        elif ask "Start the daily Spotlight file index timer?"; then
            sudo systemctl start plocate-updatedb.timer && ok "Spotlight index timer started"
        fi
    fi

    if [[ "${SHELL:-}" != *zsh ]] && ask "Set zsh as your default shell?"; then
        chsh -s "$(command -v zsh)" && ok "default shell set to zsh (re-login to apply)"
    fi
}

verify_install() {
    info "Verification"
    local failures=0 cmd
    local required=(niri qs kanshi wallust awww wl-copy cliphist wpctl nmcli bluetoothctl \
        brightnessctl playerctl grim slurp magick jq fd plocate python3 notify-send \
        xdg-open gpu-screen-recorder kitty zsh starship git zstd curl)
    for cmd in "${required[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then err "missing runtime command: $cmd"; failures=$((failures + 1)); fi
    done

    if command -v niri >/dev/null 2>&1; then
        niri validate -c "$CONFIG_DST/niri/config.kdl" >/dev/null \
            && ok "Niri configuration valid" \
            || { err "Niri configuration invalid"; failures=$((failures + 1)); }
    fi
    [[ -r /usr/share/oh-my-zsh/oh-my-zsh.sh ]] \
        && ok "Oh My Zsh framework available" \
        || { err "Oh My Zsh framework missing"; failures=$((failures + 1)); }
    [[ -L "$HOME/.cache/current_wallpaper" && -r "$HOME/.cache/wal/colors.json" ]] \
        && ok "wallpaper and generated palette initialized" \
        || { warn "wallpaper/theme state has not been initialized"; failures=$((failures + 1)); }

    if [[ -n "${WAYLAND_DISPLAY:-}" && -x "$(command -v qs 2>/dev/null || true)" ]]; then
        local qs_log qs_status=0
        qs_log=$(mktemp)
        timeout --signal=TERM --kill-after=1 4 qs -p "$CONFIG_DST/quickshell" --no-color >"$qs_log" 2>&1 || qs_status=$?
        if [[ $qs_status -eq 124 || $qs_status -eq 137 ]] && grep -q 'Configuration Loaded' "$qs_log"; then
            ok "Quickshell launch test passed"
        elif [[ $qs_status -eq 0 ]] && grep -q 'Configuration Loaded' "$qs_log"; then
            ok "Quickshell launch test passed"
        else
            err "Quickshell launch test failed"
            sed -n '1,80p' "$qs_log" >&2
            failures=$((failures + 1))
        fi
        rm -f "$qs_log"
    else
        warn "Quickshell launch test deferred until a Wayland session is active"
    fi

    if (( failures > 0 )); then
        err "$failures verification check(s) failed"
        return 1
    fi
    ok "installation is internally consistent"
}

# ── Done ─────────────────────────────────────────────────────────────────────
final_notes() {
    cat <<EOF

$(printf "${c_green}Done.${c_reset}") The desktop core, wallpaper and generated theme are ready.

  Optional per-machine refinements:

  1. Add explicit monitor/dock profiles only when needed:
       $CONFIG_DST/niri/includes/host.kdl
       $CONFIG_DST/kanshi/config

  2. Lock-screen face icon:
       cp your-photo.jpg ~/.face.icon

  Select "Niri" in your display manager, or run `niri-session` from a TTY.
EOF
}

main() {
    preflight
    if (( CHECK_ONLY )); then verify_install; exit $?; fi
    info "Bootstrapping from: $REPO_DIR"
    if ask "Install dependencies (pacman + AUR + omz plugins)?"; then install_deps; else warn "skipping dependency install"; fi
    if [[ "$INSTALL_OPTIONAL" == "0" ]]; then
        warn "skipping optional personal apps"
    elif ask "Install optional personal apps (browser, editor, office, TUIs)?"; then
        install_optional
    else
        warn "skipping optional personal apps; matching keybinds will remain dormant"
    fi
    seed_host_config
    link_configs
    seed_personal_config
    initialize_wallpaper
    post_setup
    verify_install
    final_notes
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
