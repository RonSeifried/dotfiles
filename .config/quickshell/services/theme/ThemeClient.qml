pragma Singleton
import QtQuick
import Quickshell
import "lib/palette.js" as Palette
import "../settings"

// Consumer-facing theme API. Three property-groups: colors / fonts / metrics.
// Stage A: pulls from LocalThemeProvider. Stage B: dual-mode with D-Bus daemon.
Singleton {
    id: root

    // ── colors ───────────────────────────────────────────────────
    // Semantic aliases over LocalThemeProvider raw slots. bg from slot0,
    // accents/muted contrast-enforced for legibility on bgVariant. Signal
    // colours are HUE-AWARE (see Palette.signalColor): salience slots carry
    // no fixed hue, so error/success/warning pick the palette slot nearest
    // the semantic anchor hue instead of trusting slot numbers.
    readonly property QtObject colors: QtObject {
        readonly property color bg:        Palette.neutralize(LocalThemeProvider.color0, 0.18)
        readonly property color bgVariant: Palette.neutralize(
            Palette.mix(LocalThemeProvider.color0, LocalThemeProvider.color8, 0.30), 0.16)
        // Neutral elevated tone (scrims, thumbnail overlays) — derived from
        // bg, NOT a chromatic slot: slot1 has an arbitrary hue per wallpaper.
        readonly property color surface:   Palette.neutralize(
            Palette.mix(LocalThemeProvider.color0, LocalThemeProvider.color8, 0.15), 0.12)
        readonly property color accent:    Palette.ensureContrast(LocalThemeProvider.color6, bgVariant, 4.5)
        readonly property color accentAlt: Palette.ensureContrast(LocalThemeProvider.color5, bgVariant, 4.5)
        readonly property color text:      Palette.ensureContrast(
            Palette.neutralize(LocalThemeProvider.color15, 0.04), bgVariant, 7.0)
        readonly property color textMuted: Palette.ensureContrast(
            Palette.neutralize(LocalThemeProvider.color7, 0.06), bgVariant, 4.5)
        // Chromatic candidates for signal hues (bright slots included — they
        // diverge from 1–6 once the wallust templates lighten them).
        readonly property var _chroma: [
            LocalThemeProvider.color1,  LocalThemeProvider.color2,  LocalThemeProvider.color3,
            LocalThemeProvider.color4,  LocalThemeProvider.color5,  LocalThemeProvider.color6,
            LocalThemeProvider.color9,  LocalThemeProvider.color10, LocalThemeProvider.color11,
            LocalThemeProvider.color12, LocalThemeProvider.color13, LocalThemeProvider.color14
        ]
        readonly property color success:   Palette.ensureContrast(Palette.signalColor(_chroma, Palette.HUE_SUCCESS), bg, 4.5)
        readonly property color warning:   Palette.ensureContrast(Palette.signalColor(_chroma, Palette.HUE_WARNING), bg, 4.5)
        readonly property color error:     Palette.ensureContrast(Palette.signalColor(_chroma, Palette.HUE_ERROR), bg, 4.5)

        // Raw slot passthrough (back-compat for forwarder Colors.qml)
        readonly property color color0:  LocalThemeProvider.color0
        readonly property color color1:  LocalThemeProvider.color1
        readonly property color color2:  LocalThemeProvider.color2
        readonly property color color3:  LocalThemeProvider.color3
        readonly property color color4:  LocalThemeProvider.color4
        readonly property color color5:  LocalThemeProvider.color5
        readonly property color color6:  LocalThemeProvider.color6
        readonly property color color7:  LocalThemeProvider.color7
        readonly property color color8:  LocalThemeProvider.color8
        readonly property color color9:  LocalThemeProvider.color9
        readonly property color color10: LocalThemeProvider.color10
        readonly property color color11: LocalThemeProvider.color11
        readonly property color color12: LocalThemeProvider.color12
        readonly property color color13: LocalThemeProvider.color13
        readonly property color color14: LocalThemeProvider.color14
        readonly property color color15: LocalThemeProvider.color15

        // Content-accent / state alphas (surface tints now live in `elevation`).
        readonly property real pillHoverAlpha:  0.22
        readonly property real dividerAlpha:    0.22
        readonly property real sliderTrackAlpha:0.20
    }

    // ── fonts ────────────────────────────────────────────────────
    readonly property QtObject fonts: QtObject {
        // Proportional UI font (macOS-like). Nerd-Font glyph icons resolve via
        // a fontconfig fallback (see .config/fontconfig/conf.d/10-inter-nerd*).
        // `icon` is kept explicit for glyph-only Texts that want to be immune to
        // the fallback (and as a clean seam if we ever drop the fontconfig rule).
        readonly property string family: "Inter"
        readonly property string icon:   "JetBrainsMono Nerd Font"
        readonly property int tiny:   10
        readonly property int small:  11
        readonly property int normal: 12
        readonly property int medium: 13
        readonly property int large:  14
    }

    // ── metrics ──────────────────────────────────────────────────
    readonly property QtObject metrics: QtObject {
        // Bar
        readonly property int barHeight:        36
        readonly property int barMargin:        8
        // Bar floats with a uniform 8px inset (top = sides = niri gaps) so the
        // gap above/below/around windows reads identically everywhere.
        readonly property int barTopMargin:     8
        // Layer-shell already accounts for the top margin. Reserving it again
        // created barMargin + niri gap below the bar (16 logical px).
        readonly property int barExclusiveZone: 36
        readonly property int pillHeight:       28
        // Visible controls stay compact; pointer/focus targets meet a more
        // forgiving desktop minimum without making the menu bar look bulky.
        readonly property int hitTarget:        36

        // Radii — macOS-26 squircle feel (generously rounded).
        readonly property int radiusPill:    999
        readonly property int radiusXL:      20   // panels / large floating sheets
        readonly property int radiusLarge:   16   // tiles, cards
        readonly property int radiusMedium:  12   // inner controls, search fields
        readonly property int radiusSmall:   8
        readonly property int radiusTiny:    6

        // Spacing
        readonly property int spacingTight:  4
        readonly property int spacingSmall:  6
        readonly property int spacingNormal: 8
        readonly property int spacingLarge:  12
        readonly property int spacingXL: 16

        // Interaction feedback (see Animation Grammar)
        readonly property real hoverBrightness: 0.09   // restrained macOS-like hover wash
        readonly property real pressScale:      0.97   // scale on press

        // Animation durations
        // Set QS_REDUCED_MOTION=1 to retain state changes while suppressing
        // spatial/infinite motion. Components use these effective durations.
        readonly property bool motionEnabled: SettingsState.motion !== "off"
        readonly property real motionScale: SettingsState.motion === "reduced" ? 0.55 : 1.0
        readonly property int durFast:     motionEnabled ? Math.round(90 * motionScale) : 0
        readonly property int durNormal:   motionEnabled ? Math.round(125 * motionScale) : 0
        readonly property int durSlide:    motionEnabled ? Math.round(145 * motionScale) : 0
        readonly property int durEnter:    motionEnabled ? Math.round(190 * motionScale) : 0

        // Panel
        readonly property int panelPadding: 12
        readonly property int popupGap:     6

        // Launcher
        readonly property int launcherWidth:      520
        readonly property int launcherMinWidth:   360
        readonly property int launcherMaxHeight:  480
        readonly property int launcherTopMargin:  88
        readonly property int searchBarHeight:    44
        readonly property int appItemHeight:      38
        readonly property int resultItemHeight:   46
        readonly property int appIconSize:        22
        readonly property int hintBarHeight:      28
    }

    // ── ink ──────────────────────────────────────────────────────
    // White-alpha levels for fills ON glass (tracks, badges, grooves).
    // One source instead of scattered Qt.rgba(1,1,1,x) literals — hover
    // washes keep using metrics.hoverBrightness.
    readonly property QtObject ink: QtObject {
        readonly property real track: 0.18   // slider / OSD track
        readonly property real idle:  0.22   // idle icon-badge fill (GlassTile)
        readonly property real dim:   0.28   // muted/inactive active-fill
        readonly property real veil:  0.35   // muted OSD fill
        readonly property real fill:  0.55   // active white fill (slider groove)
    }

    // ── elevation ────────────────────────────────────────────────
    // Glass surface tiers. Each = (tint over bgVariant, white top-edge
    // highlight, accent hairline border — the "good bar" edge applied uniformly).
    readonly property QtObject elevation: QtObject {
        readonly property real adaptiveDensity: SettingsState.adaptiveMaterial ? WallpaperState.density : 1.0
        // e1 — flush/low: bar pills, inline chips
        readonly property real e1TintAlpha:      Math.min(1, 0.68 * SettingsState.materialOpacity * adaptiveDensity)
        readonly property real e1HighlightAlpha: 0.06
        readonly property real e1BorderAlpha:    0.20
        // e2 — raised: popups, cards
        readonly property real e2TintAlpha:      Math.min(1, 0.90 * SettingsState.materialOpacity * adaptiveDensity)
        readonly property real e2HighlightAlpha: 0.08
        readonly property real e2BorderAlpha:    0.14
        // e3 — floating: launcher, modal overlays
        // Floating sheets need enough body that terminal/editor text cannot
        // remain readable through them when compositor blur is unavailable.
        readonly property real e3TintAlpha:      Math.min(1, 0.96 * SettingsState.materialOpacity * adaptiveDensity)
        readonly property real e3HighlightAlpha: 0.10
        readonly property real e3BorderAlpha:    0.20
    }
}
