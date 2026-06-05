# CLAUDE.md

Personal dotfiles for an Arch Linux + **niri** (Wayland compositor) desktop with
a custom shell built in **Quickshell** (Qt/QML). Single-user, multi-machine
(laptop + desktop).

## Install / linking

- Bootstrap a machine with `./install.sh` (run from any clone path — the repo is
  NOT tied to `~/dotfiles`). It installs deps and links configs.
- Linking uses **GNU stow under the hood** (`--no-folding`, per-file). Do not
  link by hand; re-running `install.sh` is idempotent.
- Dependencies live in `packages/{pacman,aur,omz-plugins}.txt` (single source).

## Machine-specific vs shared

- **Shared** = everything tracked in the repo.
- **Machine-local** (never tracked): niri monitor outputs in
  `.config/niri/includes/host.kdl` (gitignored, seeded from `host.kdl.example`),
  and `~/.config/kanshi/config`. niri pulls host.kdl via
  `include optional=true`.
- Generated files (wallust palette output) and secrets (API keys, e.g.
  `zed/settings.json`) are gitignored — never commit them.

## Theming

- `wallust` turns the wallpaper into `~/.cache/wal/colors.json`; the shell reads
  it live via Quickshell `FileView` (no restart on theme change).
- Never hardcode signal colors (success/error/warn). Drive everything from the
  palette + dynamic rules. See `~/.config/wallust/templates/`.

## Quickshell layout (`.config/quickshell/`)

- `services/<name>/` — framework-pure singletons (WMState, theme, audio,
  network, mpris, notifications, polkit, control, performance, mcp), each with a
  `qmldir`. All singletons are globally available by type name.
- `bar/`, `launcher/`, `menus/`, `osd/` — UI composition.
- `lock/` — a **separate qs instance**; it cannot import the main singletons, so
  it has its own theme files. Keep shared logic in importable files, not copies.
- `Colors.qml` / `Theme.qml` — back-compat forwarders over `services/theme/`.

## Working conventions

- Quickshell **hot-reloads** on file change — don't restart `qs` to test.
- The lock screen runs as its own `qs -p .../lock` instance.
- This is a personal setup: not published, not multi-WM. Don't add abstraction
  for distribution (no AUR packaging, no compositor-abstraction layer).
