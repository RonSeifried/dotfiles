pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."
// lib/palette.js is a relative SYMLINK to ../services/theme/lib/palette.js —
// qs sandboxes each instance to its config root (imports outside are
// blackholed), so the shared file must appear inside lock/.
import "lib/palette.js" as Palette

// Mirrors main Colors.qml — lock runs as its own qs instance and cannot
// import the main singleton (colour MATH is shared via lib/palette.js).
// Live-loads from ~/.cache/wal/colors.json (written by wallust).
// FileView watchChanges → no qs respawn on theme change.
Singleton {
    id: root

    property var _palette: ({})
    property bool _animate: false

    readonly property string colorsPath:
        (Quickshell.env("HOME") || "") + "/.cache/wal/colors.json"

    // ── Raw palette (animated) ───────────────────────────────────
    property color color0:  _palette.color0  ? _palette.color0  : "#1d2021"
    property color color1:  _palette.color1  ? _palette.color1  : "#cc241d"
    property color color2:  _palette.color2  ? _palette.color2  : "#98971a"
    property color color3:  _palette.color3  ? _palette.color3  : "#d79921"
    property color color4:  _palette.color4  ? _palette.color4  : "#458588"
    property color color5:  _palette.color5  ? _palette.color5  : "#b16286"
    property color color6:  _palette.color6  ? _palette.color6  : "#689d6a"
    property color color7:  _palette.color7  ? _palette.color7  : "#a89984"
    property color color8:  _palette.color8  ? _palette.color8  : "#928374"
    property color color15: _palette.color15 ? _palette.color15 : "#ebdbb2"

    Behavior on color0  { enabled: root._animate; ColorAnimation { duration: LockTheme.durColor; easing.type: Easing.OutCubic } }
    Behavior on color1  { enabled: root._animate; ColorAnimation { duration: LockTheme.durColor; easing.type: Easing.OutCubic } }
    Behavior on color2  { enabled: root._animate; ColorAnimation { duration: LockTheme.durColor; easing.type: Easing.OutCubic } }
    Behavior on color3  { enabled: root._animate; ColorAnimation { duration: LockTheme.durColor; easing.type: Easing.OutCubic } }
    Behavior on color4  { enabled: root._animate; ColorAnimation { duration: LockTheme.durColor; easing.type: Easing.OutCubic } }
    Behavior on color5  { enabled: root._animate; ColorAnimation { duration: LockTheme.durColor; easing.type: Easing.OutCubic } }
    Behavior on color6  { enabled: root._animate; ColorAnimation { duration: LockTheme.durColor; easing.type: Easing.OutCubic } }
    Behavior on color7  { enabled: root._animate; ColorAnimation { duration: LockTheme.durColor; easing.type: Easing.OutCubic } }
    Behavior on color8  { enabled: root._animate; ColorAnimation { duration: LockTheme.durColor; easing.type: Easing.OutCubic } }
    Behavior on color15 { enabled: root._animate; ColorAnimation { duration: LockTheme.durColor; easing.type: Easing.OutCubic } }

    // ── Semantic aliases (lock-scoped; math shared via palette.js) ─
    readonly property color background: color0
    readonly property color text:       color15
    readonly property color textMuted:  Palette.ensureContrast(color7, color0, 3.0)
    readonly property color accent:     Palette.ensureContrast(color6, color0, 4.5)
    readonly property color accentAlt:  Palette.ensureContrast(color5, color0, 4.5)
    // Hue-aware: salience slots have no fixed hue, so "Failed" red is picked
    // by hue distance, not slot number (see Palette.signalColor).
    readonly property color error: Palette.ensureContrast(
        Palette.signalColor([color1, color2, color3, color4, color5, color6], Palette.HUE_ERROR),
        color0, 4.5)

    // ── File watcher ─────────────────────────────────────────────
    FileView {
        id: paletteFile
        path: root.colorsPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const j = JSON.parse(text())
                if (j && j.colors) root._palette = j.colors
                if (!root._animate) Qt.callLater(() => root._animate = true)
            } catch (e) {
                console.warn("LockColors: failed to parse colors.json:", e)
            }
        }
        onLoadFailed: console.warn("LockColors: colors.json missing — using fallback palette")
    }
}
