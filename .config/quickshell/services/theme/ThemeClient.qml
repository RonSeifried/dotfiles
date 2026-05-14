pragma Singleton
import QtQuick
import Quickshell

// Consumer-facing theme API. Three property-groups: colors / fonts / metrics.
// Stage A: pulls from LocalThemeProvider. Stage B: dual-mode with D-Bus daemon.
Singleton {
    id: root

    // ── colors ───────────────────────────────────────────────────
    // Semantic aliases over LocalThemeProvider raw slots. Same wallust
    // salience model as previous Colors.qml: bg from slot0, accents
    // contrast-enforced for legibility on bgVariant/bg.
    readonly property QtObject colors: QtObject {
        readonly property color bg:        LocalThemeProvider.color0
        readonly property color bgVariant: LocalThemeProvider.mix(LocalThemeProvider.color0, LocalThemeProvider.color8, 0.30)
        readonly property color surface:   LocalThemeProvider.color1
        readonly property color accent:    LocalThemeProvider.ensureContrast(LocalThemeProvider.color6, bgVariant, 4.5)
        readonly property color accentAlt: LocalThemeProvider.color5
        readonly property color text:      LocalThemeProvider.color15
        readonly property color textMuted: LocalThemeProvider.color7
        readonly property color success:   LocalThemeProvider.ensureContrast(LocalThemeProvider.color2, bg, 4.5)
        readonly property color warning:   LocalThemeProvider.ensureContrast(LocalThemeProvider.color3, bg, 4.5)
        readonly property color error:     LocalThemeProvider.ensureContrast(LocalThemeProvider.color1, bg, 4.5)

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

        // Opacity helpers — surface tuning across the shell
        readonly property real pillBgAlpha:     0.68
        readonly property real pillBorderAlpha: 0.55
        readonly property real pillHoverAlpha:  0.22
        readonly property real popupBgAlpha:    0.74
        readonly property real dividerAlpha:    0.22
        readonly property real sliderTrackAlpha:0.20
    }

    // ── fonts ────────────────────────────────────────────────────
    readonly property QtObject fonts: QtObject {
        readonly property string family: "JetBrainsMono Nerd Font"
        readonly property int tiny:   9
        readonly property int small:  10
        readonly property int normal: 11
        readonly property int medium: 12
        readonly property int large:  13
    }

    // ── metrics ──────────────────────────────────────────────────
    readonly property QtObject metrics: QtObject {
        // Bar
        readonly property int barHeight:        36
        readonly property int barMargin:        8
        readonly property int barTopMargin:     6
        readonly property int barExclusiveZone: 42
        readonly property int pillHeight:       28

        // Radii
        readonly property int radiusPill:    999
        readonly property int radiusLarge:   14
        readonly property int radiusMedium:  12
        readonly property int radiusSmall:   8
        readonly property int radiusTiny:    6

        // Spacing
        readonly property int spacingTight:  4
        readonly property int spacingSmall:  6
        readonly property int spacingNormal: 8
        readonly property int spacingLarge:  12

        // Animation durations
        readonly property int durFast:     120
        readonly property int durNormal:   180
        readonly property int durSlide:    220
        readonly property int durHover:    150
        readonly property int durColor:    380

        // Panel
        readonly property int panelPadding: 10
        readonly property int popupGap:     4

        // Launcher
        readonly property int launcherWidth:      440
        readonly property int launcherMaxHeight:  480
        readonly property int launcherTopMargin:  100
        readonly property int searchBarHeight:    40
        readonly property int appItemHeight:      38
        readonly property int resultItemHeight:   46
        readonly property int appIconSize:        22
        readonly property int hintBarHeight:      22
    }
}
