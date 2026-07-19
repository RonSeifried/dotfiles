pragma Singleton
import QtQuick
import Quickshell
import "lib/palette.js" as Palette   // symlink into lock/ (see LockColors.qml)

// Lock runs as its own qs instance (qs -p ~/.config/quickshell/lock) and
// cannot import the main Theme singleton. Mirror the values needed by the
// lock surface here. Keep in sync with ../Theme.qml when changing shared
// tokens (fontFamily, durSlide, spacing, radii).
QtObject {
    // ── Font ─────────────────────────────────────────────────────
    readonly property string fontFamily: "Inter"
    readonly property string fontIcon:   "JetBrainsMono Nerd Font"

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
    readonly property bool motionEnabled: Quickshell.env("QS_REDUCED_MOTION") !== "1"
    readonly property int durSlide: motionEnabled ? 220 : 0

    // ── Password input ───────────────────────────────────────────
    readonly property int inputWidth:  320
    readonly property int inputHeight: 44
    readonly property int inputBorder: 1

    // ── Frost material — single source in services/theme/lib/palette.js,
    // shared with components/GlassSurface (no more sync-by-comment).
    readonly property real frostFillAlpha:      Palette.frost.fill
    readonly property real frostBorderAlpha:    Palette.frost.border
    readonly property real frostHighlightAlpha: Palette.frost.highlight
    readonly property real frostPillFillAlpha:  Palette.frost.pillFill

    // ── Backdrop (blurred wallpaper, macOS lock look) ────────────
    readonly property real scrimAlpha: 0.35
    readonly property real blurAmount: 1.0
    readonly property int  blurMax:    64

    // ── New tokens (lockscreen redesign) ─────────────────────────
    readonly property int fontPercent:       11
    readonly property int batteryPillHeight: 28
    readonly property int batteryMargin:     16
    readonly property int shakeAmplitude:    motionEnabled ? 8 : 0
    readonly property int durShake:          motionEnabled ? 420 : 0
    readonly property int durColor:          motionEnabled ? 380 : 0
    readonly property real clockOffsetY:     -0.10   // fraction of parent height
    readonly property real inputOffsetY:      0.05
}
