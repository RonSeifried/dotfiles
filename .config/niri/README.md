# Niri Config

Niri is a **scrollable tiling Wayland compositor**. Unlike Hyprland, windows are arranged in columns on an infinite horizontal strip — the screen is a viewport you scroll through, not a grid that fills automatically.

## Core Concept

- Windows live in **columns**. Each column can have multiple windows stacked vertically.
- Columns scroll horizontally — open as many as you want.
- Each monitor has its own independent workspace list.
- `Mod` = **Super (Windows key)**

---

## Keybinds

### Programs

| Bind | Action |
|---|---|
| `Super+T` | Terminal (kitty) |
| `Super+B` | Browser (zen-browser) |
| `Super+Shift+B` | Browser private window |
| `Super+D` | Discord (webcord) |
| `Super+C` | Code editor (Zed) |
| `Super+N` | Notes (Obsidian) |
| `Super+Shift+N` | Document editor (LibreOffice) |
| `Super+Shift+E` | File manager (Nautilus) |
| `Super+Space` | App launcher (Rofi) |

### Scripts & Tools

| Bind | Action |
|---|---|
| `Super+E` | File manager TUI (yazi, floating) |
| `Super+Shift+T` | Task manager (taskwarrior-tui, floating) |
| `Super+A` | AI assistant |
| `Super+P` | Package installer |
| `Super+G` | Wallpaper switcher (menu) |
| `Super+Shift+S` | Next wallpaper |
| `Super+Shift+G` | Random wallpaper |
| `Super+M` | MCP server manager |
| `Super+R` | Display resolution menu |
| `Super+V` | Clipboard history (cliphist) |

### System

| Bind | Action |
|---|---|
| `Super+Q` | Close focused window |
| `Super+F` | Toggle fullscreen |
| `Super+Shift+F` | Toggle maximize column |
| `Super+Shift+M` | True maximize (fills screen, no gaps) |
| `Super+Shift+V` | Toggle floating/tiling |
| `Super+Alt+L` | Lock screen (swaylock) |
| `Super+Shift+L` | Power menu (shutdown/reboot/suspend) |
| `Super+Shift+P` | Turn off monitors |
| `Super+F1` | Show all keybinds overlay |
| `Super+O` | Overview (zoomed-out workspace view) |
| `Ctrl+Alt+Delete` | Quit niri |

### Night Mode

| Bind | Action |
|---|---|
| `Super+F9` | Night mode on (4500K warm) |
| `Super+Shift+F9` | Night mode off |
| `Super+F10` | Night mode warm (3000K) |

### Screenshots

| Bind | Action |
|---|---|
| `Print` | Screenshot UI (select area) |
| `Ctrl+Print` | Screenshot full screen |
| `Alt+Print` | Screenshot focused window |
| `Shift+Print` | Screen recorder |

### Focus Navigation

| Bind | Action |
|---|---|
| `Super+H` / `Super+Left` | Focus column left |
| `Super+L` / `Super+Right` | Focus column right |
| `Super+J` / `Super+Down` | Focus window below (in column) |
| `Super+K` / `Super+Up` | Focus window above (in column) |
| `Super+Home` | Focus first column |
| `Super+End` | Focus last column |
| `Alt+Tab` | Focus previous window |
| `Super+Tab` | Go to previous workspace |

### Move Windows

| Bind | Action |
|---|---|
| `Super+Ctrl+H/L` | Move column left/right |
| `Super+Ctrl+J/K` | Move window down/up in column |
| `Super+Shift+Left/Right/Up/Down` | Move column to other monitor |
| `Super+Ctrl+Shift+H/J/K/L` | Move column to monitor (hjkl) |

### Workspaces

| Bind | Action |
|---|---|
| `Super+1-9, 0` | Switch to workspace 1–10 |
| `Super+Shift+1-9, 0` | Move window to workspace 1–10 |
| `Super+U` / `Super+Page_Down` | Next workspace |
| `Super+I` / `Super+Page_Up` | Previous workspace |
| `Super+Ctrl+U/I` | Move column to next/prev workspace |
| `Super+WheelDown/Up` | Scroll through workspaces |

### Column & Width Operations

| Bind | Action |
|---|---|
| `Super+Ctrl+R` | Cycle preset widths (1/3 → 1/2 → 2/3) |
| `Super+-` / `Super+=` | Shrink/grow column width by 10% |
| `Super+Shift+-` / `Super+Shift+=` | Shrink/grow window height by 10% |
| `Super+Ctrl+F` | Expand column to fill available space |
| `Super+Ctrl+C` | Center focused column |
| `Super+Shift+C` | Center all visible columns |
| `Super+W` | Toggle tab display in column |

### Stacking Windows in Columns

> This is niri-specific — you can stack multiple windows in one column.

| Bind | Action |
|---|---|
| `Super+,` | Pull next window INTO current column (stack below) |
| `Super+.` | Expel bottom window OUT of column |
| `Super+[` | Move window to/from column on the left |
| `Super+]` | Move window to/from column on the right |

---

## Key Differences from Hyprland

| Feature | Hyprland | Niri |
|---|---|---|
| Layout | Tiling grid | Scrollable columns |
| Lock key | `Super+L` | `Super+Alt+L` (L is used for hjkl nav) |
| Fullscreen | `Super+F` | `Super+F` ✓ |
| Maximize | — | `Super+Shift+F` (column) / `Super+Shift+M` (window) |
| Float toggle | — | `Super+Shift+V` |
| Scratchpad | `special:drop` | Not available |
| Blur | Yes | Not available |
| Window dim | Yes | Not available |
| Monitor profiles | hyprdynamicmonitors | kanshi |
| Lock screen | hyprlock | swaylock |
| Idle | hypridle | swayidle |

## Autostart

Started by niri on login:
- **waybar** — top bar
- **swaync** — notification center
- **swayosd-server** — volume/brightness OSD
- **kanshi** — monitor profile switching
- **swayidle** — screen lock + DPMS (240s off, 300s lock)
- **cliphist** — clipboard history
- **gnome-keyring** — SSH/secrets keyring
- **lxqt-policykit-agent** — privilege escalation dialogs

## Monitor Profiles (kanshi)

Config: `~/.config/kanshi/config`

- **docked**: Both external monitors, laptop screen disabled
- **laptop**: Laptop screen only (scale 1.333)

Run `niri msg outputs` to see current output names/descriptions.

## Pywal Colors

Borders update automatically on wallpaper change via wallust hook.  
Manual update: `~/.config/scripts/pywal-niri-colors.sh`
