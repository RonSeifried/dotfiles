# rshell — End-Vision Design Doc

**Status:** Design (validated 2026-05-14). Not yet implemented.
**Scope:** End-state architecture for splitting `~/.config/quickshell/` into a standalone `rshell` package. Inspired by caelestia-shell + dots, noctalia, dank-shell.

---

## 1. Understanding Summary

- **What:** Standalone `rshell`-Paket — installierbarer Linux-Desktop-Shell mit eigener Settings-App, Rust-daemon, D-Bus-IPC, pluggable theming.
- **Why:** Echte Persistenz, build/install statt zerstreute Shell-Scripts, Settings-App für non-edit-config-changes, Repo-split erlaubt unabhängiges rshell-versioning + Distribution.
- **Wer:** Primär Ron. Secondary: andere niri-User auf Arch (AUR-target). Multi-WM Architektur-offen aber nicht heute implementiert.
- **Schlüssel-Constraints:** niri-first, Arch-first, qs-basiert (kein web/gtk), single-maintainer-Komplexität.
- **Non-Goals (heute):** hyprland/sway-backends, multi-distro, web-settings-app, daemon-owns-everything-rewrite.

---

## 2. Decision Log

| # | Entscheidung | Alternativen | Warum gewählt |
|---|--------------|--------------|---------------|
| 1 | End-vision designen vor implementation | Phase-3-Start jetzt; Feasibility-Recherche | User wollte Design-Klarheit, dann später execute |
| 2 | Niri-first, shareable | Personal-only; multi-WM-now; multi-distro | Sweet-spot zwischen YAGNI und Distribution-Vision |
| 3 | Rust für daemon + scripts | Go; Python; Mix | Compiled, single-binary, top-tier system-libs (zbus/rusqlite/notify), passt zu qt-shell-quality |
| 4 | TOML config + SQLite state | Alles SQLite; alles TOML; D-Bus-state-only | Klare Trennung user-edit (TOML) vs runtime (SQLite); beide standard, gute Rust-libs |
| 5 | Settings-App = qs-Window | Qt6 nativ; Tauri; Web-localhost | Shared theme/components mit shell, ein tech-stack, kein style-drift |
| 6 | Single rshelld + small helpers | Mehrere kleine daemons; kein daemon; hybrid | Single source of truth, einfachste IPC-API, klein-genug-scope |
| 7 | D-Bus session bus | Unix-socket+JSON-RPC; hybrid file+dbus | Canonical, qs hat built-in support, debuggbar via busctl |
| 8 | Pluggable ThemeProvider | Tokens-im-config + pywal-sync; hardcoded | Maximale Flex, settings-app wird interessant, mehrere theme-sources sauber abbildbar |
| 9 | Runtime-feature-toggles | Compile-time cargo-features; hybrid | User-friendly, settings-app kann togglen, optional-deps fail-graceful |
| 10 | Strikte Repo-trennung | Pragmatisch (rshell shippt shell.qml); hybrid skeleton-cli | Sauberer split, dotfiles bleibt user-layout-choice |
| 11 | Approach B (qs-heavy, daemon = Persistenz/IPC) | Daemon-heavy; pure-qml-no-daemon | Minimaler rewrite, qs behält native bindings, daemon scope klein |
| 12 | Settings-App = Window in main qs-instance | Eigene qs-instance | Zero overhead bei visible:false, snappy open, single qml-engine |
| 13 | State1 = generic kv + typed interfaces für queryable lists | Alles generic; alles typed | Vermeidet generic-kv-becomes-the-API anti-pattern, typed-interfaces für notif-history/wallpaper-history |

---

## 3. Final Design

### 3.1 Repo Layout

#### rshell/ (eigenständig, AUR-target)
```
rshell/
├── PKGBUILD
├── crates/
│   ├── rshelld/                    # main daemon (Rust, tokio, zbus, rusqlite)
│   │   └── src/{main.rs, config/, store/, ipc/, theme/, helpers/, features/}
│   ├── rshell-cli/                 # one-shot binaries: screenshot, pickcolor, reload, settings
│   └── rshell-common/              # shared types: Tokens, Config, IPC-DTOs
├── qml/                            # → /usr/lib/qt6/qml/Rshell/
│   ├── qmldir
│   ├── services/                   # framework-pure singletons + reusable UI-modules
│   │   ├── audio/ network/ mpris/ notifications/ polkit/ mcp/ performance/
│   │   ├── theme/                  # ThemeClient (D-Bus consumer)
│   │   ├── daemon/                 # DaemonClient (D-Bus shim, reconnect-loop)
│   │   ├── wm/                     # WMState (niri-backend, abstraction für später)
│   │   └── ui-state/               # PopupState (popup-routing)
│   ├── components/
│   │   ├── bar/ launcher/ menus/ lock/ osd/
│   │   └── settings/               # Settings-window + pages
│   └── default-themes/             # bundled curated static themes (.toml)
├── system/
│   ├── systemd/user/rshelld.service
│   └── udev/99-rshell-charge-threshold.rules
├── share/applications/rshell-settings.desktop
└── docs/
```

#### dotfiles/ (bleibt)
```
.config/
├── niri/ kanshi/ kitty/ wallust/ swayidle/
├── quickshell/
│   ├── shell.qml        # 30-Zeilen-stub: import Rshell; layout-choice
│   └── lock/shell.qml
├── scripts/             # nicht-rshell scripts (pywal-niri-colors, fastfetch-launcher)
└── wallpapers/
```

### 3.2 rshelld Scope

**Module:** `config` (TOML load+watch+schema), `store` (SQLite + migrations), `ipc` (zbus-server + auth), `theme` (ThemeProvider trait + 3 backends), `helpers` (tokio-tasks für perf-stat / lid-watcher / threshold-restore), `features` (runtime-flag-dispatch).

**Lifecycle:** systemd-user-unit, `Restart=on-failure`, `RestartSec=2s`, `WantedBy=graphical-session.target`. Crash-recovery via qs-side reconnect-loop.

**Boundary:** Pipewire/NetworkManager/Mpris2/FDO-Notifications bleiben qs-side native. Daemon archiviert nur was Persistenz braucht (notif-history via D-Bus-spy).

**Performance-budget:** Idle <5MB RSS, <0.1% CPU. Theme-broadcast <16ms end-to-end. perf-stat 1Hz, ~2MB overhead.

### 3.3 D-Bus API (`org.rshell.Daemon`)

| Interface | Path | Zweck |
|-----------|------|-------|
| `org.rshell.Daemon1` | `/org/rshell/Daemon` | Lifecycle: Ping, Reload, ListFeatures + Version, Uptime, ConfigReloaded, Shutdown signals |
| `org.rshell.Theme1` | `/org/rshell/Theme` | GetTokens, SetBackend, ApplyStaticTheme + TokensChanged, BackendChanged signals |
| `org.rshell.Config1` | `/org/rshell/Config` | Get/Set/GetAll/Reset(key) + KeyChanged signal |
| `org.rshell.Performance1` | `/org/rshell/Performance` | Snapshot + StartStream/StopStream (ref-counted) + Sample signal (1Hz) |
| `org.rshell.State1` | `/org/rshell/State` | Generic kv: Get/Set/Delete/Keys(namespace) für ad-hoc primitives |
| `org.rshell.NotifHistory1` | `/org/rshell/NotifHistory` | Query(filter)/Add/Clear für queryable notif-archive |
| `org.rshell.WallpaperHistory1` | `/org/rshell/WallpaperHistory` | Query/Add/Clear für recent + usage-counts |

**Auth:** zbus peer-uid-check. **Versioning:** Interface-suffix `1` ermöglicht parallel `Theme2` ohne breaking.

### 3.4 Persistenz-Schema

**`~/.config/rshell/config.toml`** — settings-app-output via `toml_edit` (Kommentare bleiben). Sections: `[theme]`, `[features]`, `[bar]`, `[wallpaper]`, `[performance]`, `[mcp]`, `[lock]`, `[paths]`. `schema_version = 1` für migrations.

**`~/.local/state/rshell/state.db`** — SQLite via `rusqlite_migration`. Tabellen:
- `kv (namespace, key, value, type_hint, updated)` — ad-hoc primitives
- `notif_history (id, received, app_name, summary, body, urgency, actions, dismissed)` mit retention 30d, vacuum-on-startup
- `wallpaper_history (path, last_used, use_count)` — unlimited, klein
- `theme_cache (backend, tokens_json, updated)` — schnellstart

### 3.5 ThemeProvider Abstraction

**Trait:** `ThemeProvider { name, current_tokens, watch(broadcast::Sender<Tokens>), shutdown }`.

**Tokens:** colors (semantic: accent/bg/text/error etc.), fonts (family, size_base), metrics (gap_*, radius_*, dur_*).

**Backends:**
- `WallustBackend` — `~/.cache/wal/colors.json` via inotify, mit user-overrides aus `[theme]` gemerged
- `StaticBackend` — `default-themes/<name>.toml` (shipped) oder `~/.config/rshell/themes/<name>.toml` (user)
- `SystemBackend` — KDE color-scheme oder GTK settings, adapt color-keys

**Fonts/metrics IMMER aus `[theme]`-section** über alle backends — pywal liefert nur colors. SystemBackend kann font übernehmen wenn `theme.font_family = "system"` (sentinel).

**Switching at runtime:** atomar — `current.shutdown(); current = new; current.watch(); broadcast`.

**qs-side `ThemeClient.qml`** — singleton mit `colors/fonts/metrics`-properties, D-Bus-proxy + reconnect-loop. `Colors.qml` und `Theme.qml` werden thin-wrappers. `Behavior on color { ColorAnimation { duration: ThemeClient.metrics.dur_color } }` für smooth-transitions.

### 3.6 Settings-App

**Lifecycle:** zusätzliches `Window` in laufender shell-qs-instance, `visible: false` default. Show via D-Bus-call `org.rshell.shell.Settings.Open()` (CLI-binary `rshell-settings` ist trivialer busctl-wrapper).

**Window:** 960×720, frameless, eigenes blur, sidebar-nav + content-pane, themed via ThemeClient (dogfood).

**Pages:** Theme · Bar · Lock · Performance · MCP · Wallpaper · Features · About.

**Write-flow:** UI-control → `Config.Set(key, value)` D-Bus → daemon validates + writes TOML + emits `KeyChanged` → alle clients re-bind.

**Live-preview:** sliders mit 150ms debounce, slider-release = final-write, ESC = restore-from-cache.

### 3.7 Migration Path (Stage A → F)

| Stage | Inhalt |
|-------|--------|
| **A** Phase-2 finish | NiriState→services/wm/, Colors/Theme→services/theme/ mit LocalThemeProvider-fallback, ControlState-split (popup-routing→services/ui-state/) |
| **B** Daemon bootstrap | rshell-repo init, Cargo workspace, Theme1-interface, ThemeClient dual-mode (daemon ODER local-fallback), Settings-stub |
| **C** Scripts → Rust | perf-stat, kanshi-lid-watcher, threshold-restore als helpers; screenshot/pickcolor als CLI-binaries; wallpaper-switcher hybrid (apply→daemon, traversal→CLI-shim) |
| **D** Settings-app full | Alle pages, notif-archive, wallpaper-history, feature-flags wirklich toggle-bar |
| **E** Repo-split & PKGBUILD | rshell tree packen, dotfiles/quickshell auf 30-zeilen-stub schrumpfen, scripts purgen, makepkg local |
| **F** Multi-machine | 2nd machine pacman-rshell + stow-dotfiles, config-toml sync via dotfiles oder per-machine-overrides |

---

## 4. Assumptions (NFR)

| Bereich | Annahme |
|---------|---------|
| Performance | Token-broadcast sub-frame (16ms). perf-stat 1Hz. Daemon idle <5MB. |
| Reliability | rshelld systemd-user, Restart=on-failure. qs gracefully degraded ohne daemon (cached tokens, settings unreachable, UI bleibt funktional). |
| Security | User-scope nur. Polkit nur für sysfs (heutiges udev-pattern bleibt). MCP secrets in `~/.docker/mcp/`. |
| Versioning | rshelld + qml-module + settings-app shipped together (one PKGBUILD, one version). qs hot-reload nach pacman-Syu. |
| Maintenance | Solo-maintainer. Komplexität minimal. Ein Daemon, ein TOML-schema, ein D-Bus-namespace. |
| Migration | Phase-2 services lifted wholesale. NiriState/Colors/Theme/ControlState müssen abstrahiert werden VOR repo-split. |

---

## 5. Risks & Open Questions

**Risks:**
1. **Daemon-IPC-overhead** für theme-tokens. Mitigation: tokens-cache qml-side, nur diff-broadcast, batch slider-updates 150ms.
2. **Migration-disruption** während Stage A-D — täglicher Setup könnte temp gebrochen sein. Mitigation: dual-mode ThemeClient (daemon ODER fallback), Stage-by-stage merge in main, kein big-bang-cutover.
3. **Settings-app dogfooding** — wenn settings-app sich selbst broken konfiguriert wird sie unbenutzbar. Mitigation: `rshell-cli reset` CLI-fallback, schema-validation rejected bad-writes vor commit.
4. **Wallust-coupling** in WallustBackend — user kann wallust deinstallieren. Mitigation: Backend self-disables wenn `~/.cache/wal/` fehlt + emits warning, fallback auf StaticBackend(default).
5. **Multi-WM future-proofing** — services/wm/ shape muss heute schon WM-agnostic interface haben, sonst hyprland-port später teuer. Mitigation: Stage A lifts NiriState mit explizitem trait-shape, niri-backend ist nur erste impl.

**Out-of-scope (later phases):**
- Multi-WM backends (hyprland/sway)
- Multi-distro packaging (Fedora, Debian, NixOS)
- Theme-marketplace (community static themes)
- Plugin-system für third-party shell-modules
- Mobile/touch-friendly settings-layout

---

## 6. Implementation Handoff Notes

Dieses Dokument ist End-Vision. Für konkrete impl-arbeit:
1. Stage A (Phase-2 finish) ist die nächste actionable schicht — wird als separate planning-session aufgeschlüsselt
2. Stage B (rshell-repo init) wartet bis Stage A komplett ist (services müssen self-contained sein)
3. Decision-log + risks oben sind referenz für jeden Stage-PR

**Reference-Implementations zum Schauen wenn Stage B beginnt:**
- caelestia-shell (qs-based, eigene settings, eigene config)
- noctalia (qs-based, multi-WM)
- dank-shell (qs-based)
