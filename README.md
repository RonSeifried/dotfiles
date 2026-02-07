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
| **Color Scheme** | [Pywal](https://github.com/dylanaraps/pywal) |
| **Wallpaper** | [swww](https://github.com/LGFae/swww) |
| **Lock Screen** | Hyprlock + Hypridle |
| **Browser** | Zen Browser |
| **Git UI** | [Lazygit](https://github.com/jesseduffield/lazygit) |
| **MCP Management** | [Docker MCP Gateway](https://docs.docker.com/ai/mcp-catalog-and-toolkit/) via Rofi |

## 📦 Dependencies

### Core Packages (pacman)

```bash
sudo pacman -S hyprland kitty waybar rofi neovim yazi zsh starship \
  swww swaync hypridle hyprlock python-pywal nautilus \
  brightnessctl playerctl wl-clipboard grim slurp grimblast \
  bluez bluez-utils networkmanager gnome-keyring
```

### AUR Packages (paru/yay)

```bash
paru -S oh-my-zsh-git zsh-autosuggestions zsh-syntax-highlighting \
  zsh-you-should-use zsh-bat eza neofetch fastfetch hyprpicker \
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

5. **Set up Pywal with your wallpaper:**

```bash
wal -i /path/to/your/wallpaper.jpg
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
│   ├── wal/            # Pywal colorschemes
│   ├── waybar/         # Status bar
│   ├── yazi/           # File manager
│   └── zed/            # Zed editor
├── .zshrc              # ZSH configuration
├── .zprofile           # ZSH profile (env vars)
├── .gitignore          # Git ignore rules
└── .stow-local-ignore  # Stow ignore rules
```

## 🎨 Theming

This setup uses **Pywal** for dynamic color schemes based on your wallpaper.

### Change Wallpaper & Theme

```bash
# Set new wallpaper and generate colors
wal -i /path/to/wallpaper.jpg

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

The default AUR helper is set to `paru`. Change it in `.zshrc`:

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