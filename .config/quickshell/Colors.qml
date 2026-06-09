pragma Singleton
import QtQuick
import Quickshell

// Back-compat forwarder. Real palette lives in services/theme/LocalThemeProvider
// (raw slots + animation Behaviors) and services/theme/ThemeClient (semantic
// aliases). All historic Colors.* properties remain available unchanged.
Singleton {
    // Raw slots — from animated source
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

    // Semantic aliases — from ThemeClient
    readonly property color bg:        ThemeClient.colors.bg
    readonly property color bgVariant: ThemeClient.colors.bgVariant
    readonly property color surface:   ThemeClient.colors.surface
    readonly property color accent:    ThemeClient.colors.accent
    readonly property color accentAlt: ThemeClient.colors.accentAlt
    readonly property color text:      ThemeClient.colors.text
    readonly property color textMuted: ThemeClient.colors.textMuted
    readonly property color success:   ThemeClient.colors.success
    readonly property color warning:   ThemeClient.colors.warning
    readonly property color error:     ThemeClient.colors.error

    // Opacity helpers (surface tints now via Theme.elevation tiers)
    readonly property real pillHoverAlpha:  ThemeClient.colors.pillHoverAlpha
    readonly property real dividerAlpha:    ThemeClient.colors.dividerAlpha
    readonly property real sliderTrackAlpha:ThemeClient.colors.sliderTrackAlpha
}
