# 🏠 Dotfiles

Personal dotfiles for Arch Linux with Hyprland, managed with GNU Stow.

## 📸 Screenshots

<!-- Add screenshots here -->

## 🔧 Components

| Component | Tool |
|-----------|------|
| **Window Manager** | [Hyprland](https://hyprland.org/) |
| **Terminal** | [Kitty](https://sw.kovidgoyal.net/kitty/) |
| **Shell** | ZSH + [Oh My ZSH](https://ohmyz.sh/) + [Starship](https://starship.rs/) |
| **Editor** | [Neovim](https://neovim.io/) (LazyVim) |
| **File Manager** | [Yazi](https://yazi-rs.github.io/) (TUI) / Nautilus (GUI) |
| **Launcher** | [Rofi](https://github.com/davatorium/rofi) |
| **Bar** | [Waybar](https://github.com/Alexays/Waybar) |
| **Notifications** | [SwayNC](https://github.com/ErikReider/SwayNotificationCenter) |
| **Color Scheme** | [Wallust](https://codeberg.org/explosion-mental/wallust) |
| **Wallpaper** | [awww](https://codeberg.org/LGFae/awww) |
| **Lock Screen** | Hyprlock + Hypridle |
| **Browser** | Zen Browser |
| **Git UI** | [Lazygit](https://github.com/jesseduffield/lazygit) |
| **MCP Management** | [Docker MCP Gateway](https://docs.docker.com/ai/mcp-catalog-and-toolkit/) via Rofi |

## 📦 Dependencies

### Core Packages (pacman)

```bash
sudo pacman -S hyprland kitty hyprpolkitagent hyprsunset waybar rofi neovim yazi zsh starship tmux jq \
  awww swaync hypridle hyprlock wallust nautilus gum fzf plocate \
  brightnessctl playerctl wl-clipboard grim slurp grimblast \
  bluez bluez-utils networkmanager gnome-keyring
```

### AUR Packages (yay)

```bash
yay -S oh-my-zsh-git zsh-autosuggestions zsh-syntax-highlighting \
  zsh-you-should-use eza neofetch fastfetch hyprpicker gpu-screen-recorder serie tv \
  zen-browser-bin webcord-bin
```

### Oh My ZSH Plugins

```bash
# zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# you-should-use
git clone https://github.com/MichaelAquilina/zsh-you-should-use.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/you-should-use

# zsh-bat
git clone https://github.com/fdellwing/zsh-bat.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-bat
```

## 🚀 Installation

1. **Clone the repository:**

```bash
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

2. **Backup existing configs (optional but recommended):**

```bash
mv ~/.zshrc ~/.zshrc.backup
mv ~/.config/hypr ~/.config/hypr.backup
# ... etc
```

3. **Install with GNU Stow:**

```bash
stow .
```

This will symlink all dotfiles to your home directory.

4. **Set ZSH as default shell:**

```bash
chsh -s $(which zsh)
```

5. **Set up Wallust with your wallpaper:**

```bash
wallust run -q /path/to/your/wallpaper.jpg
```

6. **Reboot or re-login to apply changes.**

## ⌨️ Keybindings

### Applications

| Keybind | Action |
|---------|--------|
| `Super + T` | Terminal (Kitty) |
| `Super + B` | Browser |
| `Super + Shift + B` | Browser (Private) |
| `Super + C` | Code Editor |
| `Super + D` | Discord |
| `Super + N` | Notes (Obsidian) |
| `Super + Shift + N` | Document Editor (LibreOffice) |
| `Super + E` | File Manager (Yazi dropdown) |
| `Super + Shift + E` | File Manager (Nautilus) |
| `Super + Space` | App Launcher (Rofi) |

### Window Management

| Keybind | Action |
|---------|--------|
| `Super + Q` | Close Window |
| `Super + F` | Fullscreen |
| `Super + Arrow Keys` | Move Focus |
| `Super + 1-0` | Switch Workspace |
| `Super + Shift + 1-0` | Move Window to Workspace |
| `Super + Mouse Scroll` | Scroll Workspaces |
| `Super + LMB` | Move Window |
| `Super + RMB` | Resize Window |

### System

| Keybind | Action |
|---------|--------|
| `Super + L` | Lock Screen |
| `Super + Shift + L` | Power Off |
| `Print` | Screenshot (Area) |
| `Super + G` | Wallpaper Switcher |
| `Super + A` | AI Assistant (Rofi) |
| `Super + M` | MCP Management |
| `Super + P` | Package Installer |

### Media Keys

| Key | Action |
|-----|--------|
| `Volume Up/Down/Mute` | Audio Control |
| `Brightness Up/Down` | Screen Brightness |
| `Play/Pause/Next/Prev` | Media Control |

## 📁 Structure

```
dotfiles/
├── .config/
│   ├── hypr/           # Hyprland config (modular)
│   │   ├── modules/    # Keybinds, style, env, etc.
│   │   └── scripts/    # Hypr-specific scripts
│   ├── kitty/          # Terminal config
│   ├── nvim/           # Neovim (LazyVim)
│   ├── rofi/           # Launcher themes
│   ├── scripts/        # General scripts
│   │   └── rofi/       # Rofi menu scripts (wifi, vpn, mcp, …)
│   ├── starship/       # Prompt config
│   ├── swaync/         # Notification center
│   ├── wal/            # Wallust configs
│   ├── waybar/         # Status bar
│   ├── yazi/           # File manager
│   └── zed/            # Zed editor
├── .zshrc              # ZSH configuration
├── .zprofile           # ZSH profile (env vars)
├── .gitignore          # Git ignore rules
└── .stow-local-ignore  # Stow ignore rules
```

## 🎨 Theming

This setup uses **Wallust** for dynamic color schemes based on your wallpaper.

### Change Wallpaper & Theme

```bash
# Set new wallpaper and generate colors
wallust run -q /path/to/wallpaper.jpg

# Or use the built-in wallpaper switcher
Super + G
```

Colors are automatically applied to:
- Hyprland borders
- Kitty terminal
- Waybar
- Rofi
- Starship prompt

## 🛠️ Customization

### AUR Helper

The default AUR helper is set to `yay`. Change it in `.zshrc`:

```bash
export aurhelper="yay"  # or your preferred helper
```

### Programs

Edit `~/.config/hypr/modules/programs.conf` to change default applications.

### Monitor Setup

Create `~/.config/hypr/modules/monitors.conf` (machine-specific, not tracked by git):

```bash
monitor=DP-1,2560x1440@144,0x0,1
monitor=HDMI-A-1,1920x1080@60,2560x0,1
```

## 🐳 MCP Management (Docker MCP Gateway)

The MCP Management menu (`Super + M`) provides full control over the Docker MCP Gateway directly from Rofi:

| Submenu | Actions |
|---------|---------|
| **Catalog** | List catalogs, show default catalog, init catalog |
| **Servers** | List/enable/disable/inspect MCP servers |
| **Gateway** | Start gateway, list tools, tool count |
| **Auth & Secrets** | OAuth provider authorization, list secrets |

### Requirements

- **Docker Engine** (not Docker Desktop)
- **Docker MCP plugin** (`docker mcp` CLI)

The script checks for both dependencies on launch and shows a notification if either is missing.

## 📝 Notes

- The `zed/settings.json` is gitignored because it contains API keys. Copy from `zed/settings.json.example` if provided.
- Monitor configuration is machine-specific and not tracked.
- Fastfetch is preferred over Neofetch for faster shell startup.

## 📜 License

MIT License - feel free to use and modify as you like!
## 🪟 Tmux (Terminal Multiplexer)

This setup includes a beginner-friendly `tmux` configuration (`~/.config/tmux/tmux.conf`). Tmux allows you to have multiple terminal sessions, windows, and split panes inside a single terminal window, which stay alive even if you close the terminal.

### Basic Usage

The "prefix" key is your master key for all tmux commands. It has been changed from the default `Ctrl+B` to **`Ctrl+Space`** for better ergonomics.

1.  **Start tmux:** `tmux` (or just open the terminal dropdown `Super + E / Super + Shift + T` which uses tmux under the hood)
2.  **Split Panes:**
    *   `Ctrl+Space` then `|` (split vertically / side-by-side)
    *   `Ctrl+Space` then `-` (split horizontally / top-bottom)
3.  **Navigate Panes:** You can just use your **Mouse** to click between panes, or resize them by dragging the borders!
4.  **New Window (Tab):** `Ctrl+Space` then `c` (create)
5.  **Switch Windows:** `Ctrl+Space` then `1`, `2`, `3`, etc.
6.  **Detach (Leave running in background):** `Ctrl+Space` then `d`
7.  **Reattach (Bring it back):** `tmux attach`

You can reload the configuration anytime with `Ctrl+Space` then `r`.
