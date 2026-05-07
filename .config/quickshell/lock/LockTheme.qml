pragma Singleton
import QtQuick

// Lock runs as its own qs instance (qs -p ~/.config/quickshell/lock) and
// cannot import the main Theme singleton. Mirror the values needed by the
// lock surface here. Keep in sync with ../Theme.qml when changing shared
// tokens (fontFamily, durSlide, spacing, radii).
QtObject {
    // ── Font ─────────────────────────────────────────────────────
    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    // Lock-specific font sizes (clock/date are larger than anywhere in main)
    readonly property int fontClock:  96
    readonly property int fontDate:   14
    readonly property int fontInput:  13
    readonly property int fontStatus: 11

    // ── Spacing ──────────────────────────────────────────────────
    readonly property int spacingNormal: 8
    readonly property int spacingLarge:  12

    // ── Radii ────────────────────────────────────────────────────
    readonly property int radiusPill: 999

    // ── Animation durations ──────────────────────────────────────
    readonly property int durSlide: 220

    // ── Password input ───────────────────────────────────────────
    readonly property int inputWidth:  360
    readonly property int inputHeight: 48
    readonly property int inputBorder: 2

    // ── New tokens (lockscreen redesign) ─────────────────────────
    readonly property int fontPercent:       11
    readonly property int batteryPillHeight: 28
    readonly property int batteryMargin:     16
    readonly property int shakeAmplitude:    8
    readonly property int durShake:          420
    readonly property int durColor:          380
    readonly property real clockOffsetY:     -0.10   // fraction of parent height
    readonly property real inputOffsetY:      0.05
    readonly property real overlayAlpha:      0.35
}
