pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Daemon-less local fallback. Live-reads ~/.cache/wal/colors.json (wallust output),
// animates raw palette slots. Stage B will introduce a D-Bus-fed alternative
// provider; ThemeClient stays the same consumer surface.
Singleton {
    id: root

    property var _palette: ({})
    property bool _animate: false

    readonly property string colorsPath:
        (Quickshell.env("HOME") || "") + "/.cache/wal/colors.json"

    // Animated raw palette slots (color0..color15) with smooth ColorAnimation Behaviors.
    // Animations stay here because semantic bindings in ThemeClient transitively
    // animate when their source slot animates.
    property color color0:  _palette.color0  ? _palette.color0  : "#1d2021"
    property color color1:  _palette.color1  ? _palette.color1  : "#cc241d"
    property color color2:  _palette.color2  ? _palette.color2  : "#98971a"
    property color color3:  _palette.color3  ? _palette.color3  : "#d79921"
    property color color4:  _palette.color4  ? _palette.color4  : "#458588"
    property color color5:  _palette.color5  ? _palette.color5  : "#b16286"
    property color color6:  _palette.color6  ? _palette.color6  : "#689d6a"
    property color color7:  _palette.color7  ? _palette.color7  : "#a89984"
    property color color8:  _palette.color8  ? _palette.color8  : "#928374"
    property color color9:  _palette.color9  ? _palette.color9  : "#fb4934"
    property color color10: _palette.color10 ? _palette.color10 : "#b8bb26"
    property color color11: _palette.color11 ? _palette.color11 : "#fabd2f"
    property color color12: _palette.color12 ? _palette.color12 : "#83a598"
    property color color13: _palette.color13 ? _palette.color13 : "#d3869b"
    property color color14: _palette.color14 ? _palette.color14 : "#8ec07c"
    property color color15: _palette.color15 ? _palette.color15 : "#ebdbb2"

    // Palette cross-fade. Hardcoded constant (matches Theme.durNormal = 180) to
    // avoid a circular Theme.qml dependency — keep in sync with durNormal.
    Behavior on color0  { enabled: root._animate; ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on color1  { enabled: root._animate; ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on color2  { enabled: root._animate; ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on color3  { enabled: root._animate; ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on color4  { enabled: root._animate; ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on color5  { enabled: root._animate; ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on color6  { enabled: root._animate; ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on color7  { enabled: root._animate; ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on color8  { enabled: root._animate; ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on color9  { enabled: root._animate; ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on color10 { enabled: root._animate; ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on color11 { enabled: root._animate; ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on color12 { enabled: root._animate; ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on color13 { enabled: root._animate; ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on color14 { enabled: root._animate; ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on color15 { enabled: root._animate; ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

    // ── WCAG contrast helpers (public — used by ThemeClient) ─────
    function lum(c) {
        function f(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b)
    }
    function ratio(a, b) {
        const la = lum(a), lb = lum(b)
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
    }
    function ensureContrast(fg, bg, target) {
        if (ratio(fg, bg) >= target) return fg
        const step = lum(bg) < 0.5 ? 0.02 : -0.02
        let l = fg.hslLightness
        for (let i = 0; i < 60; ++i) {
            l += step
            if (l < 0 || l > 1) break
            const adj = Qt.hsla(fg.hslHue, fg.hslSaturation, l, fg.a)
            if (ratio(adj, bg) >= target) return adj
        }
        return fg
    }
    function mix(a, b, t) {
        return Qt.rgba(a.r * (1 - t) + b.r * t,
                       a.g * (1 - t) + b.g * t,
                       a.b * (1 - t) + b.b * t, 1)
    }

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
                console.warn("LocalThemeProvider: failed to parse colors.json:", e)
            }
        }
    }
}
