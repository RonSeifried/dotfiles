# Design Philosophy — Niri + Quickshell Setup

> Source of truth für die Migration von Hyprland-Setup (waybar/rofi/swaync/hyprlock) auf
> einen vollständig in Quickshell gebauten Shell auf Niri.
> Alles, was hier steht, ist die verbindliche Design-Sprache. Neue Komponenten
> müssen sich daran ausrichten — sonst zerfällt die Kohärenz wieder in Inseln.

---

## 1. Vision

**„Quiet, warm, scrollable."**

Drei Worte beschreiben, was diese Shell sein soll und was nicht:

- **Quiet** (von Noctalia): Die Shell drängt sich nicht auf. Keine Knall-Animationen,
  keine Dauer-Notifications, keine ablenkenden Akzente. Sie ist da, wenn man sie
  ruft, und verschwindet sauber, wenn man sie loslässt. Top-Bar ist sichtbar, alles
  andere lebt in Overlays/Popups.
- **Warm** (von Wallust + alter Hyprland-Look): Pywal/Wallust generiert die Palette
  aus dem Wallpaper. Die Default-Stimmung ist nicht klinisch-kalt (kein Material-You-
  Lavendel, kein Catppuccin-Mauve) sondern warm, getragen vom Wallpaper. `Colors.qml`
  morpht die Palette mit `ColorAnimation` über 380 ms — kein Flash beim
  Wallpaper-Wechsel.
- **Scrollable** (von Niri): Die Shell respektiert das horizontale Scroll-Paradigma.
  Workspace-Indikator ist linear, nicht gridig. Overview ist horizontal-zoom-out, nicht
  ein Grid wie unter Hyprland.

**Was wir nicht sind:**

- Kein Material You / M3 Klon (das ist end-4/dots-hyprland Territorium).
- Kein Glassmorphism-Heavy (keine 0.4-Layer wie Caelestia).
- Kein Material-Symbols-Rounded — wir bleiben bei JetBrainsMono Nerd Font für
  alles, inklusive Icons. Ein Font für die ganze Shell.
- Keine Dock unten. Niri hat keine, wir bauen keine. App-Switching geht über
  Launcher + Workspace-Scroll.

---

## 2. Inspiration-Matrix

| Quelle | Was wir übernehmen | Was wir lassen |
|---|---|---|
| **Noctalia** | „Quiet by design" — Shell stays out of the way. Warmes Lavendel-Wallpaper-Theming als mentales Modell für Color-Generation. Setup-Wizard-Idee für später. | Plugin-Ökosystem (Overkill für Personal-Setup). Lavendel-Default. |
| **Caelestia** | Right-Side Dashboard-Pattern (Status-Cluster expandiert in vollwertige Panels). Per-Monitor Workspaces. Command-Mode im Launcher (`>` für Aktionen) als Ziel. | Glassmorphism-Heavy (0.4 Opacity). Bongo-Cat. Beat-Detector. Material-Symbols-Font. |
| **DankMaterialShell** | Client-Server-Trennung als Architektur-Idee (wir haben das implizit über `qs ipc call`). Spotlight-Style-Launcher zentriert. Wallpaper → System-weit Theming via Wallust (statt matugen). | Go-Backend (zu komplex). Material-Design-3-Schicht. „Dank16" CLI-Color-System. |
| **end-4 / illogical-impulse** | Komplette Shell aus Quickshell, Waybar weg. Sidebar für Settings/AI als langfristiges Ziel. Overview-Animation als Referenz. | Material You. Mobile-OS-Anmutung. „ii" vs „waffle" Panel-Familien. AI-Sidebar (haben wir extern via `askai.sh`). |
| **eigenes Hyprland-Setup** | Pywal/Wallust Color-Pipeline. Pill-Architektur (3 Pills: workspaces \| center \| status). Rofi-Wallpaper-Picker mit Image-Spalte → übernommen in `WallpaperPicker.qml`. Border-Radius 10–12 px, Border-Width 3 px für Fenster. | Waybar als JSON-config-getriebene Bar. Rofi für jedes Menü. swaync als externer Dienst. hyprlock als externer Lock. |

---

## 3. Visual Language

### 3.1 Farben

Alle Farben kommen aus `~/.cache/wal/colors.json` (von Wallust generiert) und werden in
`Colors.qml` als animierte Properties exposed. **Keine** harten Hex-Werte in Komponenten
außer in `Colors.qml`-Fallbacks und im Lock-Screen (`#1a1410` als Pre-Wallpaper-BG).

**Semantische Aliase** (das sind die einzigen Namen, die Komponenten verwenden dürfen):

| Alias | Quelle | Rolle |
|---|---|---|
| `bg` | `color0` | Haupt-Hintergrund (Bar-BG, Popup-BG) |
| `bgVariant` | `color8` | Pill-Hintergrund, Panel-BG (mit Alpha) |
| `surface` | `color1` | Erhöhte Flächen (Search-Bar in Launcher) |
| `accent` | `color4` | Borders, Selected-State, Hover-Highlights, Badges |
| `accentAlt` | `color12` | Sekundär-Akzent (z. B. Active-Workspace-Glow) |
| `text` | `color15` | Primary Text |
| `textMuted` | `color7` | Secondary Text, deaktivierte Icons |
| `success` | `color2` | VPN aktiv, BT verbunden, Charging |
| `warning` | `color3` | Battery-Low |
| `error` | `color1` | Battery-Critical, Failed-State |

**Opacity-Konventionen** (zentral in `Colors.qml`):

| Wert | Verwendung |
|---|---|
| `pillBgAlpha = 0.85` | Pill-Hintergrund (workspaces, status, center) |
| `pillBorderAlpha = 0.45` | Pill-Border |
| `pillHoverAlpha = 0.18` | Hover-Overlay auf Pill-Items |
| `popupBgAlpha = 0.92` | Launcher, PowerMenu, ClipboardMenu |
| `dividerAlpha = 0.20` | Vertikale Trenner zwischen Status-Items |
| `sliderTrackAlpha = 0.20` | OSD-Slider, Volume-Slider in AudioPanel |

**Wallpaper-Wechsel** ist die wichtigste „Animation" der ganzen Shell — die Palette
morpht über 380 ms `Easing.OutCubic`. Das fühlt sich an, als atmet die Shell mit dem
Wallpaper.

### 3.2 Geometrie

Alle Werte zentral in `Theme.qml`. Komponenten lesen nur Theme-Konstanten, niemals
Magic-Numbers.

| Token | Wert | Wofür |
|---|---|---|
| `radiusPill` | 999 | Bar-Pills (full pill shape) |
| `radiusLarge` | 14 | Launcher, PowerMenu, ClipboardMenu, WallpaperPicker-Panel |
| `radiusMedium` | 12 | Niri-Window-Corners (`window-rule { geometry-corner-radius 12 }`) |
| `radiusSmall` | 8 | Suchbar im Launcher, Buttons, OSD-Container |
| `radiusTiny` | 6 | Waybar-Popups (Legacy), kleine Pills innerhalb von Panels |

**Niri-Window-Border:** 3 px, `accent` für active, `bg` für inactive (geschrieben von
`pywal-niri-colors.sh`). Das ist die einzige Stelle, wo die Shell auf Wallust-Hooks
außerhalb von Quickshell angewiesen ist.

**Shadows:** Niri-Windows kriegen Shadow (softness 20, spread 5, offset y=5,
`#00000066`). Quickshell-Popups bekommen **keine** Shadows — die Pille/Panel
unterscheidet sich vom Hintergrund durch Border + Alpha, nicht durch Shadow. Das
hält den „flat, quiet" Look.

### 3.3 Spacing

| Token | Wert | Verwendung |
|---|---|---|
| `spacingTight` | 4 | Icon + Label innerhalb eines Status-Items |
| `spacingSmall` | 6 | Zwischen Pills im Bar-RowLayout |
| `spacingNormal` | 8 | Default zwischen Widgets in Panels |
| `spacingLarge` | 12 | Padding in Listen-Items, Section-Spacing in Settings |
| `panelPadding` | 10 | Innen-Padding in Popup-Panels |
| `popupGap` | 4 | Gap zwischen Bar und Popup unter der Bar |
| `barHeight` | 36 | Top-Bar |
| `barMargin` | 8 | Horizontaler Abstand der Bar zum Screen-Rand |
| `barTopMargin` | 6 | Vertikaler Abstand der Bar zum Top |
| `barExclusiveZone` | 42 | barHeight + barTopMargin → kein Window-Overlap |
| `pillHeight` | 28 | Höhe aller Pills in der Bar |

### 3.4 Typografie

**Eine Font-Familie für alles:** `JetBrainsMono Nerd Font`. Auch alle Icons sind Nerd-
Font-Glyphs (kein Material Symbols, kein Phosphor). Vorteil: ein Font-Asset, perfektes
Vertical-Alignment zwischen Text und Icon.

| Token | Pixel-Size | Verwendung |
|---|---|---|
| `fontTiny` | 9 | Notification-Badge-Count |
| `fontSmall` | 10 | Section-Header in Panels |
| `fontNormal` | 11 | Default-Body, Workspace-Numbers |
| `fontMedium` | 12 | Status-Text (Volume %, Battery %) |
| `fontLarge` | 13 | Status-Icons in Bar |
| (Lock-Clock) | 96 pt | Single Use, Light-Weight |

Keine fetten Headlines. Bold nur für Notification-Badge-Count.

### 3.5 Blur

- **Niri Blur** ist global aktiv für alle Windows (`blur { passes 3; offset 3; noise 0.02 }`)
  → das ist der Grund für die Migration überhaupt.
- **Layer-Rules** für blur sind aktiv für Rofi-Layer (Legacy) und Waybar-Popups (auch
  Legacy).
- **Quickshell-Layer-Blur** ist noch nicht aktiviert (wartet auf nächste Niri-Version,
  siehe Comment in `config.kdl`). Sobald verfügbar: `qs-popup` Namespace bekommt blur
  → Launcher/PowerMenu/etc. werden „glasige" Overlays. Bis dahin: `popupBgAlpha = 0.92`
  reicht für Lesbarkeit.

---

## 4. Layout-Map — wo lebt was

Das ist die verbindliche Antwort auf Goal 1: „what menu goes where."

### 4.1 Top-Bar (immer sichtbar, eine pro Monitor)

```
┌───────────────────────────────────────────────────────────────────────────┐
│ [Workspaces]   [Media/WindowTitle ──────────────────────] [Status Pill]   │
└───────────────────────────────────────────────────────────────────────────┘
```

**Drei Pills, gleiche Höhe (28 px), gleiche Background-Logik (`bgVariant @ 0.85`),
gleiche Border-Logik (`accent @ 0.45`).** Das ist die strengste Design-Regel der ganzen
Shell — wenn etwas in der Bar ist, ist es in einer Pill.

- **Links — Workspaces-Pill**: Punkt pro Workspace, gefüllter Punkt = aktiv. Per-Monitor.
  Klick zum Springen. Scroll-Wheel über Bar (mit `Mod`) wechselt Workspaces.
- **Mitte — Adaptive-Pill**: Wenn ein MPRIS-Player aktiv ist → Media-Player (Title +
  Play/Pause + Skip). Sonst → Window-Title des fokussierten Fensters. Übergang per
  `Loader`-sourceComponent — kein expliziter Cross-Fade nötig, QML macht das.
- **Rechts — Status-Pill**: Tray | WiFi | Bluetooth | Audio | Battery | Clock |
  Caffeine | Notification-Bell. Vertikale 1-px-Divider in `accent @ 0.3` zwischen
  Items. **Hover** öffnet Right-Panel-Popup (kein Klick nötig). **Klick** pinnt das
  Panel auf (bleibt offen bis Klick anderswo). Bottom-Corners der Pille werden
  flat (`0` statt `pillRadius`) während ein Panel offen ist — das verschmilzt Pille
  und Panel optisch zu einem Element.

### 4.2 Right-Panel-Popups (hover-driven, pinnable)

Jedes Status-Item öffnet ein Panel direkt unter dem rechten Pill-Ende. Ein Panel
ist immer eine `Rectangle` mit `radiusLarge`, `bgVariant @ 0.92`, `accent @ 0.45`
border, top-corners flat, bottom-corners rounded — visuell die Fortsetzung der Pill.

| Status-Item | Panel-Inhalt |
|---|---|
| WiFi | Available Networks, aktive Verbindung, VPN-Status, Toggle |
| Bluetooth | Devices-Liste, Connect/Disconnect, Battery der Devices |
| Audio | Default-Sink, Volume-Slider, Sink-Switcher, Mic-Mute |
| Battery | Power-Profile-Switcher, Time-Remaining, Power-Draw |
| Clock | Calendar (Monat, Today markiert) |
| Notification-Bell | Notification-Liste, Clear-All, DND-Toggle |

**Caffeine** ist ein Toggle ohne Panel. **Tray** ist visuell innerhalb der Pille,
öffnet App-eigene Menüs.

### 4.3 Overlays (zentral oder kontextuell, full-screen Layer)

Layer: `qs-popup`, `WlrLayer.Overlay`, `keyboardFocus: OnDemand`. Click-outside
schließt mit Scale-Down + Fade-Out (180 ms).

| Trigger | Overlay | Layout |
|---|---|---|
| `Mod+Space` / `qs ipc call launcher toggle` | **Launcher** | Top-Center, 100 px vom oberen Rand, 440 × max 480 px. Search-Bar oben + App-List darunter. |
| `Mod+Shift+L` / `qs ipc call power toggle` | **PowerMenu** | Center, 260 px breit. Lock/Logout/Suspend/Reboot/Shutdown. Logout/Reboot/Shutdown haben Confirm-Step (gleiches Rect, anderer Inhalt). |
| `Mod+V` / `qs ipc call clipboard toggle` | **ClipboardMenu** | Center, mittel. Cliphist-History, Search, Enter zum Kopieren. |
| `Mod+G` / `qs ipc call wallpaper toggle` | **WallpaperPicker** | Bottom-Slide-In Panel, 360 px hoch. 3D-Carousel-Style mit center/adjacent/far Größen (320×215 / 200×130 / 130×85 → siehe `panelHeight`/`centerW` Konstanten). Search filtert Files. |
| Volume/Brightness Keys | **OSD** | Top-Center oder Bottom-Center, klein (~250 × 60 px), Auto-Hide nach 1.5 s mit Fade-Out. |
| Idle-Lock | **Lock-Screen** | Full-Screen, eigener `qs -d` Process für instant Activation via IPC. Blurred Wallpaper + 96 pt Light Clock + PAM-Input. |

### 4.4 Right-Panel vs. Overlay — Entscheidungsregel

- **Right-Panel** wenn: das Item gehört zu einem Status-Indikator in der Bar und der
  Inhalt ist „dauernd aktualisierte Info + ein paar Toggles" (WiFi, BT, Audio, etc.).
- **Overlay** wenn: das Item ist eine **Aktion** (App starten, Wallpaper wählen,
  Clipboard-Eintrag wählen, System-Power) und braucht Keyboard-Focus + größere Fläche.

### 4.5 Was es (noch) nicht gibt

- **Kein Dock.** Niri-Workflow ist Launcher + Workspace-Scroll, kein Pin-Apps.
- **Keine Sidebar.** Settings landen in einem zukünftigen Settings-Overlay (siehe §9),
  nicht in einer permanenten Sidebar wie end-4.
- **Kein Desktop-Widget.** Wallpaper allein ist die Desktop-Schicht.

---

## 5. Animation-Sprache

**Eine Bewegung, eine Bedeutung.** Niri und Quickshell verwenden konsistente Easings,
damit die Shell sich anfühlt wie ein Element.

### 5.1 Niri (Compositor)

Alle Window-Animationen sind **Springs** mit identischen Parametern:

```kdl
spring damping-ratio=0.85 stiffness=700 epsilon=0.0001
```

Das gilt für: window-open, window-close, window-movement, window-resize,
workspace-switch, horizontal-view-movement, overview-open-close.

Result: alles bewegt sich mit gleicher physikalischer Charakteristik. Keine
Sonderwege für einzelne Aktionen.

### 5.2 Quickshell (Shell)

Springs sind in QML aufwändig — wir nutzen `NumberAnimation` mit konsistenten
Easings:

| Token | Dauer | Easing | Wofür |
|---|---|---|---|
| `durFast` | 120 ms | `OutQuad` | Hover-Reactions (Color-Shift, Width-Snap) |
| `durHover` | 150 ms | `OutQuad` | Caffeine-Toggle, kleine State-Shifts |
| `durNormal` | 180 ms | `OutQuad` | Popup-Open/Close (Launcher, PowerMenu, Clipboard) |
| `durSlide` | 220 ms | `OutCubic` | Slide-In/Out (Lock-Fade, WallpaperPicker bottom-slide) |
| (Color) | 380 ms | `OutCubic` | Palette-Morph bei Wallpaper-Wechsel (Singleton) |
| (Bar startup) | 350 ms | `OutCubic` | Bar fadet von y=-10, opacity 0 → 0 nach 80 ms Pause |

**Keine Bouncing-Springs in Quickshell-Popups.** Bewegung ist „resolved", nicht
„playful." Das hält den „quiet" Anspruch.

### 5.3 Open/Close Pattern (Standard für jedes Overlay)

```qml
// Open
ParallelAnimation {
    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180–200; easing: OutQuad }
    NumberAnimation { property: "scale";   from: 0.95; to: 1; duration: 180–200; easing: OutQuad }
}
// Close
SequentialAnimation {
    ParallelAnimation { /* opacity → 0, scale → 0.95, duration: 140–150 */ }
    ScriptAction { /* set ControlState.xOpen = false; reset opacity/scale */ }
}
```

Das ist in Launcher, PowerMenu, ClipboardMenu identisch — copy-paste-able. Wer ein
neues Overlay baut, nimmt diese zwei Animations.

---

## 6. Component Catalog

### 6.1 Bereits implementiert (✅ = produktionsreif, 🚧 = funktioniert, polish offen)

| Komponente | Status | Datei |
|---|---|---|
| Top-Bar (3 Pills) | ✅ | `bar/Bar.qml` |
| Workspaces-Pill | ✅ | `bar/Workspaces.qml` |
| Media-Player / Window-Title (adaptive center) | ✅ | `bar/MediaPlayer.qml`, `bar/WindowTitle.qml` |
| System-Tray | ✅ | `bar/SystemTrayWidget.qml` |
| Clock | ✅ | `bar/Clock.qml` |
| Right-Panel-Popup-Container | ✅ | `bar/popups/RightPanelPopup.qml` |
| Toast-Popup (Notifications) | 🚧 | `bar/popups/ToastPopup.qml` |
| Bluetooth/WiFi/Audio/Battery/Calendar/Notif-Panels | ✅ | `bar/panels/*.qml` |
| Launcher | ✅ | `launcher/Launcher.qml` + `AppList.qml` |
| Lock-Screen (PAM, blurred wallpaper, 96pt clock) | ✅ | `lock/*` |
| OSD (volume + brightness, auto-hide) | ✅ | `osd/Osd.qml` |
| PowerMenu (mit Confirm-Step) | ✅ | `menus/PowerMenu.qml` |
| ClipboardMenu | ✅ | `menus/ClipboardMenu.qml` |
| WallpaperPicker (3D-Carousel) | ✅ | `menus/WallpaperPicker.qml` |
| Color-Hot-Reload via FileView | ✅ | `Colors.qml` |
| State-Singletons (Audio/Network/Mpris/Notif/Niri/Control) | ✅ | `*State.qml` |
| IPC-Handler (toggle für jedes Overlay) | ✅ | `shell.qml` |

### 6.2 Noch zu bauen / migrieren

| Item | Priorität | Notiz |
|---|---|---|
| **Notification-Daemon** (swaync ablösen) | hoch | NotifState ist da, aber swaync läuft noch. Quickshell hat `Quickshell.Notifications` — Daemon-Mode aktivieren, Toast-Popup polishen, swaync aus Autostart raus. |
| **Idle-Daemon** (swayidle ablösen) | mittel | Quickshell hat `Quickshell.Idle`. Idle-Inhibitor läuft schon über systemd-inhibit — Idle-Trigger könnte komplett in QS. |
| **Kanshi ablösen?** | niedrig | Quickshell sieht `Quickshell.screens`. Kanshi ist aber stabil und einfach — kann bleiben. |
| **Settings-Overlay** | mittel | Eine zentrale Stelle für „Bar-Items togglen", „Animation-Speed", „Theme-Override". Layout: Vollbild-Overlay, links Sections, rechts Inhalt. **Inspiration: Noctalia-Wizard.** |
| **Rofi-Replacements** | niedrig | Wallpaper, Clipboard, Power schon migriert. Verbleibend: `wifi.sh`, `bluetooth.sh`, `vpn.sh`, `mcp.sh`, `resolution.sh`, `power-profile.sh`, `ai/askai.sh`. WiFi+BT könnten in die existierenden Right-Panels (statt Rofi). VPN-Toggle ins Right-Panel-WiFi. AI/MCP/Resolution bleiben Rofi (low-traffic, lohnt nicht). |
| **Workspace-Overview-Erweiterung** | niedrig | Niri hat `toggle-overview`. Eigener QS-Overview wäre Doppelarbeit. Stattdessen: in Niri-Overview die Borders/Highlights hübscher konfigurieren (siehe `recent-windows`-Block). |
| **Command-Mode im Launcher** (Caelestia-Idea) | nice-to-have | `>` im Launcher-Search → Mode-Switch zu Aktionen statt Apps. Erstmal die Kern-Shell stabilisieren. |
| **Calendar-Panel-Inhalte** | mittel | Aktuell vermutlich basic — Wochenansicht, Today-Highlight, evtl. khal-Integration. |

### 6.3 Komponenten-Bauplan (für neue Items)

Jede neue Komponente:

1. Liest **nur** `Theme.qml` und `Colors.qml` für Visuals — keine Magic-Numbers,
   keine Hex-Codes.
2. Verwendet das Standard-Open/Close-Pattern (§5.3) wenn Overlay.
3. Verwendet das Pill-Pattern (§4.1) wenn Bar-Item.
4. State lebt in einem `State.qml`-Singleton wenn shell-weit relevant, oder lokal
   im Component-Property wenn nur Overlay-intern.
5. Toggle via IPC-Handler in `shell.qml` (`qs ipc call <target> toggle`), nicht
   direkt aus Niri-Bind.

---

## 7. State & IPC

**Pattern:** Niri-Keybind → `qs ipc call <target> <function>` → IPC-Handler in
`shell.qml` mutiert `ControlState.<flag>` → Overlay-Komponente bindet `open: ControlState.<flag>`.

Vorteile:

- Niri-Config kennt nur IPC-Strings, keine internen QS-Properties.
- Jede Shell-Aktion ist von außen scriptbar (`qs ipc call ...` aus jedem Script).
- Lock läuft als **eigener qs-Process** (`spawn-at-startup "qs" "-d" "-p" "..."`)
  → instant Lock auf IPC, kein Cold-Start-Delay.

**ControlState ist das Single-Source-of-Truth-Singleton** für:

- `launcherOpen`, `powerMenuOpen`, `clipboardOpen`, `wallpaperPickerOpen`
- `rightPanel` (string: "none" | "wifi" | "bluetooth" | "audio" | "battery" | "clock" | "notif")
- `idleInhibited` (caffeine)
- `osdVolume`, `osdBrightness`, `osdVolumeVisible`, `osdBrightnessVisible`

Neue Shell-weite Toggles kommen hier rein, nicht als lokale Properties.

---

## 8. Theming-Pipeline

```
Wallpaper-Wechsel (awww/swaybg via Script)
    │
    ▼
wallust run <wallpaper>
    │
    ├─► ~/.cache/wal/colors.json           ────►  Colors.qml (FileView, watchChanges)
    │                                              → 380 ms ColorAnimation morph
    │
    ├─► colors-rofi-dark.rasi              ────►  Rofi (Legacy-Menüs)
    ├─► colors-kitty.conf                  ────►  Kitty
    ├─► waybar-style.css                   ────►  Waybar (Legacy, falls noch aktiv)
    ├─► swaync-style.css                   ────►  swaync (bis abgelöst)
    ├─► swayosd/style.css                  ────►  SwayOSD (Legacy, abgelöst)
    │
    └─► Hooks ausgeführt:
          ├─► pywal-niri-colors.sh          ────►  Niri border-colors live
          ├─► pywal-hyprland-colors.sh     ────►  Hyprland (legacy, harmlos wenn niri läuft)
          ├─► starship-color-gen.sh        ────►  Starship-Prompt
          ├─► waybar-reload (SIGUSR2)      ────►  Waybar live
          └─► swaync-client -rs            ────►  swaync live
```

**Migrationsziel:** swaync/swayosd/waybar fallen weg → Hooks für die werden gelöscht
(reduziert Wallpaper-Wechsel-Latenz weiter). Quickshell braucht **keinen Hook** — der
FileView in `Colors.qml` triggert allein.

---

## 9. Migration-Roadmap (ableitet aus §6.2)

**Phase 1 — Stabilisieren (jetzt):**

1. design.md committen, ab hier ist sie verbindlich.
2. Alle existierenden Komponenten gegen §3/§5 prüfen (Magic-Numbers raus, Easings
   konsistent, Color-Aliases statt Hex).

**Phase 2 — Notification-System ablösen:**

3. swaync aus Autostart raus, `Quickshell.Notifications` Daemon aktivieren.
4. Toast-Popup polishen (slide-in von rechts, auto-dismiss, Click → Notification-Panel).
5. swaync-style.css Hook + swaync-Config entfernen.

**Phase 3 — Settings-Overlay:**

6. Vollbild-Overlay (`Mod+I`?), links Sections (Appearance / Bar / Animations / About),
   rechts Form-Inhalt. Settings persistieren in `~/.config/quickshell/settings.json`.
7. Entry-Points: Bar/Theme/Animation-Toggles, Power-Profile, Wallpaper-Folder-Pfad.

**Phase 4 — Right-Panel-Vervollständigung:**

8. WiFi-Panel: Available-Networks-Liste mit Connect-Action (löst `wifi.sh` ab).
9. BT-Panel: Pair-Action (löst `bluetooth.sh` ab).
10. VPN-Toggle ins WiFi-Panel.

**Phase 5 — Niri-Layer-Blur aktivieren:**

11. Sobald Niri-Version mit Quickshell-Layer-Blur draußen: `qs-popup` und `qs-bar`
    Namespaces in `config.kdl` blur=true setzen → Glas-Look ohne weitere QML-Änderung.

**Phase 6 — Idle-Daemon migrieren:**

12. swayidle raus, `Quickshell.Idle` mit den gleichen Timeouts (240s monitors-off,
    300s lock).

**Cut-Off:** Phasen 1–4 sind das eigentliche Migrations-Ziel. Phase 5 ist
Niri-Version-blockiert, Phase 6 ist Bonus.

---

## 10. Verbindliche Regeln (Cheatsheet)

- **Eine Font:** JetBrainsMono Nerd Font für Text und Icons.
- **Eine Color-Quelle:** `Colors.qml` semantische Aliase. Keine Hex-Werte in Komponenten.
- **Eine Geometrie-Quelle:** `Theme.qml` Tokens. Keine Magic-Numbers.
- **Drei Bar-Pills:** Workspaces \| Adaptive-Center \| Status. Mehr nicht.
- **Hover öffnet, Klick pinnt** Right-Panels.
- **Click-outside schließt** Overlays (über transparentes MouseArea-Backdrop).
- **180/200 ms `OutQuad` für open/close**, 380 ms `OutCubic` für Color-Morphs.
- **Keine Shadows in QS-Popups** — Border + Alpha trennt vom Hintergrund.
- **Keine Sidebars, kein Dock, kein Desktop-Widget.** Nur Bar + Overlays + Lock.
- **IPC für jede Shell-Aktion**, nie direktes Property-Setzen aus Niri-Binds.
- **State in `*State.qml` Singletons**, nie in Component-Properties wenn shell-weit.
- **Keine Bouncing-Springs in QS** — „resolved, not playful."
