<div align="center">

<h1>dotfiles</h1>

<p><em>Arch Linux · Niri · Quickshell · Wayland-native · Dynamic Wallust theming</em></p>

<p>
  <img src="https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white" />
  <img src="https://img.shields.io/badge/Niri-1f1f1f?style=for-the-badge&logoColor=white" />
  <img src="https://img.shields.io/badge/Quickshell-2C2C2C?style=for-the-badge&logoColor=white" />
  <img src="https://img.shields.io/badge/Wayland-FFBC00?style=for-the-badge&logo=wayland&logoColor=black" />
</p>

<p>
  <img src="https://img.shields.io/badge/Neovim-57A143?style=for-the-badge&logo=neovim&logoColor=white" />
  <img src="https://img.shields.io/badge/ZSH-F15A24?style=for-the-badge&logo=gnu-bash&logoColor=white" />
  <img src="https://img.shields.io/badge/Tmux-1BB91F?style=for-the-badge&logo=tmux&logoColor=white" />
  <img src="https://img.shields.io/badge/GNU_Stow-4EAA25?style=for-the-badge&logo=gnu&logoColor=white" />
</p>

<p>
  <img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" />
</p>

<p>
  Scrollable tiling on <a href="https://github.com/YaLTeR/niri">niri</a>, custom shell built in
  <a href="https://quickshell.outfoxxed.me/">Quickshell</a>. Every wallpaper change regenerates
  the full color scheme — borders, bar, OSD, lock screen — live, with zero manual intervention.
</p>

</div>

---

## Screenshots

### Overview

<div align="center">
  <img src="screenshots/overview.gif" width="900"/>
</div>

<table>
  <tr>
    <td align="center"><strong>Desktop Overview</strong></td>
    <td align="center"><strong>Terminal + Fastfetch</strong></td>
  </tr>
  <tr>
    <td><img src="screenshots/desktop-overview.png" width="430"/></td>
    <td><img src="screenshots/terminal-fetch.png" width="430"/></td>
  </tr>
</table>

---

## What Makes This Setup Different

### Scrollable Tiling (Niri)

Windows live in **columns** on an infinite horizontal strip. The screen is a viewport you scroll
through, not a grid that fills automatically. Each column can stack multiple windows vertically,
each monitor has its own independent workspace list. See `.config/niri/README.md` for the full
keybind reference.

### Quickshell Custom Shell

Bar, OSDs, lock screen, power menu, wallpaper picker, notifications — all written from scratch in
QML under `.config/quickshell/`. Single design language: rounded pills, slide-in/out animations
flush with the screen edge, pywal-driven colors throughout.

| Component | File |
|---|---|
| Top bar (workspaces · window title · MPRIS · tray · clock) | `bar/Bar.qml` |
| Volume / Brightness OSD (right edge slide-in) | `osd/Osd.qml` |
| Lock screen (separate qs instance, IPC-triggered) | `lock/` |
| Power menu (`Super+Shift+L`) | `menus/PowerMenu.qml` |
| Wallpaper picker (`Super+G`) | `menus/WallpaperPicker.qml` |
| Notification center | `NotifState.qml` + panel |

### Dynamic Theming Pipeline

One command — `wallust run wallpaper.jpg` — propagates a full 16-color scheme derived from the
wallpaper to every component simultaneously. No manual color picking, no config edits.

```
Wallpaper
   │
   ▼
wallust run wallpaper.jpg
   │
   ├──▶ Kitty terminal       (.config/wallust/templates/colors-kitty.conf)
   ├──▶ Quickshell colors    (~/.cache/wal/colors.json → services/theme, live)
   ├──▶ Niri borders         (pywal-niri-colors.sh → niri msg)
   ├──▶ Starship prompt      (starship-color-gen.sh)
   ├──▶ Kitty colors         (colors-kitty.conf)
   └──▶ Firefox / Zen        (pywalfox, when installed)
```

Color templates live in `.config/wallust/templates/` — edit them to customize which color roles
map to which UI elements.

Wallpapers are also sampled at 64×64 to estimate luminance and visual complexity. Quickshell uses
that cached analysis to make glass denser over bright or busy images, while quiet wallpapers keep
the lighter material. Wallust is the only palette authority; its pywal-compatible cache format is
retained for applications that already consume `~/.cache/wal/`.

### Desktop Settings and Health

Control Center → **Desktop Settings** contains persistent appearance, menu-bar, search and
notification preferences. Settings are versioned in `~/.config/quickshell/settings.json` and are
safe to remove to restore defaults.

The same page exposes a read-only health check and an on-demand backup. The health check verifies
runtime dependencies, generated palette/wallpaper state, broken links and repository drift.
Backups contain both an atomically replaced Git bundle and the current working tree, including
uncommitted changes. The eight newest dated working-tree snapshots are retained:

```sh
~/.config/scripts/dotfiles-doctor.sh
~/.config/scripts/dotfiles-backup.sh
```

An opt-in `dotfiles-backup.timer` performs the same backup weekly.

Arch installs `plocate-updatedb.timer` as a static daily timer. It is normally
started automatically and should not be enabled manually. Check it with
`systemctl status plocate-updatedb.timer`; if inactive, start it once with
`sudo systemctl start plocate-updatedb.timer`.

### Indexed Spotlight

Normal launcher queries combine applications, open Niri windows, system actions, calculator and
unit conversions, recent clipboard text, files and a final web fallback. File results use the
`plocate` index and fall back safely to a bounded `fd` query when the database is unavailable.
Exact names, recent documents and shallow personal folders rank above build and dependency trees.
Specialist prefixes remain available (`=`, `>`, `?`, `w`, `f`, `p`, `ai`) but are not required for
ordinary searches.

### Capture Workflow

`Print` and `Ctrl+Print` save a searchable screenshot history and copy the image immediately.
Notification actions can open or reveal the result; optional Satty and Tesseract integrations add
annotation and OCR/copy-text actions. Screen recording reports through the shared live-activity
pill rather than polling a lock file.

### AI + MCP Integration

`Super+A` opens the AI assistant inside the Quickshell launcher (`ai ` mode — Gemini SSE
streaming, multi-turn history). `Super+M` opens the MCP Manager floating window — full
catalog/servers/clients/tools/secrets/gateway UI implemented in Quickshell over `docker mcp`.

### Dynamic Monitor Profiles (kanshi)

`kanshi` automatically switches between docked and laptop-only display configurations based on
connected outputs. Machine-specific monitor config (`~/.config/kanshi/config`) is intentionally
not tracked in this repo.

---

## Stack

| Component | Tool |
|-----------|------|
| Compositor | [niri](https://github.com/YaLTeR/niri) (scrollable tiling) |
| Shell / Bar / OSD / Lock | [Quickshell](https://quickshell.outfoxxed.me/) (custom QML) |
| Terminal | [Kitty](https://sw.kovidgoyal.net/kitty/) |
| Shell | ZSH + [Oh My ZSH](https://ohmyz.sh/) + [Starship](https://starship.rs/) |
| Editor | [Neovim](https://neovim.io/) (LazyVim) |
| Code Editor (GUI) | [Zed](https://zed.dev/) |
| Launcher / AI / MCP | Quickshell launcher + MCP Manager (custom QML) |
| Color Theming | [Wallust](https://codeberg.org/explosion-mental/wallust) (pywal-compatible) |
| Wallpaper | [awww](https://github.com/LGFae/awww) + swaybg overview backdrop |
| Idle daemon | [swayidle](https://github.com/swaywm/swayidle) |
| Monitor Mgmt | [kanshi](https://sr.ht/~emersion/kanshi/) |
| Notifications | Quickshell `NotifState` (D-Bus) |
| File Manager | [Yazi](https://yazi-rs.github.io/) (TUI) / Nautilus (GUI) |
| Browser | [Zen Browser](https://zen-browser.app/) |
| Git TUI | [Lazygit](https://github.com/jesseduffield/lazygit) |
| Multiplexer | [Tmux](https://github.com/tmux/tmux) |
| System Info | [Fastfetch](https://github.com/fastfetch-cli/fastfetch) |

---

## Keybindings

> Full reference: `.config/niri/README.md`. Summary below.

### Applications

| Keybind | Action |
|---------|--------|
| `Super + T` | Terminal (Kitty) |
| `Super + B` | Browser (Zen) |
| `Super + Shift + B` | Browser (Private) |
| `Super + C` | Code Editor (Zed) |
| `Super + D` | Discord |
| `Super + N` | Notes (Obsidian) |
| `Super + Shift + N` | Document Editor (LibreOffice) |
| `Super + E` | File Manager (Yazi — floating) |
| `Super + Shift + E` | File Manager (Nautilus) |
| `Super + Shift + T` | Taskwarrior (floating) |
| `Super + Space` | App Launcher (Quickshell) |

### Menus / Tools

| Keybind | Action |
|---------|--------|
| `Super + G` | Wallpaper Picker (Quickshell) |
| `Super + Shift + S` | Next Wallpaper |
| `Super + Shift + G` | Random Wallpaper |
| `Super + Shift + L` | Power Menu (Quickshell) |
| `Super + V` | Clipboard History |
| `Super + A` | AI Assistant (Quickshell launcher `ai ` mode) |
| `Super + M` | MCP Server Manager (Quickshell floating window) |
| `Super + Y` | Pick color (niri pick-color → wl-copy + toast) |

### System

| Keybind | Action |
|---------|--------|
| `Super + Alt + L` | Lock Screen (Quickshell) |
| `Super + Shift + P` | Turn off monitors |
| `Super + F1` | Show all keybinds overlay |
| `Super + O` | Overview (zoomed-out workspaces) |
| `Super + F9` | Night Mode (4500K) |
| `Super + F10` | Night Mode (3000K) |
| `Super + Shift + F9` | Night Mode Off |
| `Print` | Screenshot UI (area select) |
| `Ctrl + Print` | Screenshot full screen |
| `Alt + Print` | Screenshot focused window |
| `Shift + Print` | Screen recording |
| `Ctrl + Alt + Delete` | Quit niri |

### Window / Column Management (niri-specific)

| Keybind | Action |
|---------|--------|
| `Super + Q` | Close Window |
| `Super + F` | Fullscreen |
| `Super + Shift + F` | Maximize column |
| `Super + Shift + M` | True maximize (no gaps) |
| `Super + Shift + V` | Toggle floating/tiling |
| `Super + H/J/K/L` (or arrows) | Focus column / window |
| `Super + Ctrl + H/J/K/L` | Move column / window |
| `Super + 1–9, 0` | Switch workspace |
| `Super + Shift + 1–9, 0` | Move window to workspace |
| `Super + Ctrl + R` | Cycle preset widths (1/3 → 1/2 → 2/3) |
| `Super + - / =` | Shrink / grow column width |
| `Super + ,` | Pull next window into column (stack) |
| `Super + .` | Expel bottom window from column |
| `Super + WheelUp/Down` | Scroll workspaces |

### Media Keys

| Key | Action |
|-----|--------|
| Volume Up/Down/Mute | Audio (Quickshell OSD via wpctl) |
| Mic Mute | Microphone |
| Brightness Up/Down | Screen brightness (Quickshell OSD via brightnessctl) |
| Play/Pause/Next/Prev | Media control (playerctl) |

---

## Installation

> **Prerequisites:** A normal user account on Arch Linux with `sudo` and network access.
> Running from a TTY is supported; a live Wayland session is not required.

### 1. Clone & bootstrap

Clone anywhere — the repo is not tied to `~/dotfiles`:

```bash
git clone https://github.com/rs3c/dotfiles.git ~/dev/dotfiles
cd ~/dev/dotfiles
./install.sh
```

That single command:

- verifies the Arch/user environment;
- installs every core runtime dependency explicitly, plus the AUR helper when needed;
- optionally installs the personal applications used by keybindings;
- preserves conflicting pre-existing files in `~/.local/state/dotfiles/` before linking;
- links configs into `$HOME` with per-file GNU Stow links;
- creates safe machine-local Niri and Kanshi defaults without copying another computer's outputs;
- seeds credential-free application settings;
- selects an existing wallpaper or generates a neutral default;
- generates Wallust colors, the overview background and adaptive-material metadata;
- offers hardware services, Docker/MCP, backups and default-shell setup; and
- validates Niri, dependencies, generated state and—inside Wayland—an actual Quickshell launch.

Useful modes:

```bash
./install.sh --minimal  # complete desktop core, skip personal GUI/TUI apps
./install.sh --yes      # unattended defaults; secrets are still never invented
./install.sh --check    # read-only portability and health verification
```

The installer is idempotent and safe to rerun.

### 2. Change the initial wallpaper later (optional)

```bash
~/.config/scripts/wallpaper_switcher.sh --apply /path/to/wallpaper.jpg
```

Propagates the palette to Niri borders, Quickshell, Kitty and Starship. If
`pywalfox` is installed, compatible Firefox/Zen profiles are refreshed too —
live, no desktop restart.

### 3. Machine-specific monitor refinements (optional, not tracked)

- **Monitors (niri):** automatic compositor defaults work immediately. Add overrides to
  `.config/niri/includes/host.kdl` only when a display needs custom scale or layout.
- **Monitors (kanshi):** create `~/.config/kanshi/config` with docked / laptop
  profiles only for docking automation. The installed fallback profile is safe on any machine.
  Use the `docked_open`, `docked_closed`, and `laptop_open` names expected by the lid watcher.

  ```
  profile docked_closed {
      output eDP-1 disable
      output DP-1 mode 2560x1440@144Hz position 0,0 scale 1
  }
  profile laptop_open {
      output eDP-1 mode preferred scale 1.333
  }
  ```

### 4. Face icon for lock screen (optional)

```bash
cp your-photo.jpg ~/.face.icon   # rendered by quickshell lock surface
```

---

## Structure

```
dotfiles/
├── install.sh                       # Bootstrap: deps + stow-link (run from any path)
├── packages/                        # Dependency manifests (pacman / aur / omz-plugins)
├── CLAUDE.md                        # Project context for Claude Code
├── .config/
│   ├── niri/
│   │   ├── config.kdl               # Compositor root (includes/ split below)
│   │   ├── includes/                # input, layout, keybinds, rules, host.kdl(.example)
│   │   └── README.md                # Full niri keybind reference
│   ├── quickshell/
│   │   ├── shell.qml                # Main shell entry (bar, OSDs, menus)
│   │   ├── Theme.qml / Colors.qml   # Back-compat forwarders over services/theme/
│   │   ├── services/               # Framework-pure singletons (qmldir each):
│   │   │                            #   wm, theme, audio, network, mpris,
│   │   │                            #   notifications, polkit, control, performance, mcp
│   │   ├── bar/                     # Top bar pills
│   │   ├── osd/                     # Volume / Brightness OSD
│   │   ├── launcher/                # App launcher + AI mode
│   │   ├── menus/                   # Power, Wallpaper, Clipboard, …
│   │   └── lock/                    # Separate qs instance for lock surface
│   ├── kanshi/                      # Monitor profiles (not tracked)
│   ├── fastfetch/ · kitty/ · nvim/ · starship/ · tmux/ · yazi/ · zed/
│   ├── scripts/                     # niri hooks, wallpaper switcher, installer helpers
│   └── wallust/templates/           # Color templates per component
├── .zshrc · .zprofile
├── LICENSE · .stow-local-ignore
```

---

## Notes

- `zed/settings.json` is gitignored — it contains API keys. Copy `settings.json.example` as a
  starting point.
- The live palette is `~/.cache/wal/colors.json` (written by `wallust`), read by the shell via
  `FileView`. `Colors.qml` / `Theme.qml` are tracked back-compat forwarders over `services/theme/`.
- Machine-specific config (`kanshi/config`, niri `includes/host.kdl`) is not tracked.
- The Tmux prefix is `Ctrl+Space` (not the default `Ctrl+B`).
- Wallust templates in `.config/wallust/templates/` define which color roles map to which UI
  variables — edit these to customize color behavior without changing any app config.
- Generated Wallust output, Starship's live palette, app settings and per-host display files are
  gitignored and created locally.

### Public-repository safety

- Real application settings that may contain credentials (`zed/settings.json`, `.askai-env`,
  `.env*`, key/certificate files and common token stores) are ignored; only redacted examples are
  tracked.
- Gemini and MCP secret values are passed to helpers over stdin rather than command-line arguments.
- Dotfile backups use mode `0600` and exclude credential files, agent-local state and caches.
- Before publishing a branch, review staged content with `git diff --cached` and run
  `./install.sh --check`. Ignore rules prevent new leaks; they cannot remove a secret that was
  committed previously.
