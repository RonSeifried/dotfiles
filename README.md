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
   ├──▶ Yazi theme           (theme.toml)
   └──▶ Zen Browser          (zen-wal-refresh.sh)
```

Color templates live in `.config/wallust/templates/` — edit them to customize which color roles
map to which UI elements.

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
| Wallpaper | [awww](https://github.com/LGFae/awww) / swaybg fallback |
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

> **Prerequisites:** Arch Linux with a working Wayland session.

### 1. Clone & bootstrap

Clone anywhere — the repo is not tied to `~/dotfiles`:

```bash
git clone https://github.com/rs3c/dotfiles.git ~/dev/dotfiles
cd ~/dev/dotfiles
./install.sh
```

`install.sh` installs all dependencies (`packages/{pacman,aur,omz-plugins}.txt`),
then links every config into `$HOME` via GNU stow (per-file, so the repo can live
at any path). It is idempotent — safe to re-run. It also seeds the machine-local
niri monitor file and offers to enable services + set zsh as your shell.

### 2. Set your wallpaper and generate colors

```bash
wallust run /path/to/wallpaper.jpg
```

Propagates the palette to niri borders, Quickshell, Kitty, Starship, Yazi and
Zen — live, no restarts.

### 3. Machine-specific config (not tracked)

- **Monitors (niri):** edit `.config/niri/includes/host.kdl` (seeded from
  `host.kdl.example` by `install.sh`) with this machine's `output { … }` blocks.
- **Monitors (kanshi):** create `~/.config/kanshi/config` with docked / laptop
  profiles, e.g.:

  ```
  profile docked {
      output eDP-1 disable
      output DP-1 mode 2560x1440@144Hz position 0,0 scale 1
  }
  profile laptop {
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
├── docs/                            # backend-daemon-inventory.md, …
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
- Generated files (Yazi theme, wallust output) are excluded from stow — they are created on first
  `wallust run`.
