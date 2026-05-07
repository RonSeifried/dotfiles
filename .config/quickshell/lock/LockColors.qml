pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

// Mirrors main Colors.qml — lock runs as its own qs instance and cannot
// import the main singleton. Live-loads from ~/.cache/wal/colors.json
// (written by wallust). FileView watchChanges → no qs respawn on theme change.
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

    // ── WCAG luminance helpers (mirror main Colors.qml) ──────────
    function _lum(c) {
        function f(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b)
    }
    function _ratio(a, b) {
        const la = _lum(a), lb = _lum(b)
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
    }
    function _ensureContrast(fg, bg, target) {
        if (_ratio(fg, bg) >= target) return fg
        const step = _lum(bg) < 0.5 ? 0.02 : -0.02
        let l = fg.hslLightness
        for (let i = 0; i < 60; ++i) {
            l += step
            if (l < 0 || l > 1) break
            const adj = Qt.hsla(fg.hslHue, fg.hslSaturation, l, fg.a)
            if (_ratio(adj, bg) >= target) return adj
        }
        return fg
    }

    // ── Semantic aliases (lock-scoped) ───────────────────────────
    readonly property color background: color0
    readonly property color surface:    color1
    readonly property color text:       color15
    readonly property color textMuted:  color7
    readonly property color accent:     _ensureContrast(color6, color0, 4.5)
    readonly property color accentAlt:  color5
    readonly property color error:      _ensureContrast(color1, color0, 4.5)
    readonly property real overlayAlpha: LockTheme.overlayAlpha

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
