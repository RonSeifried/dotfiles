pragma Singleton
import QtQuick
import Quickshell

// Back-compat forwarder. Real metrics/fonts live in services/theme/ThemeClient.
Singleton {
    // Sizes
    readonly property int barHeight:        ThemeClient.metrics.barHeight
    readonly property int barMargin:        ThemeClient.metrics.barMargin
    readonly property int barTopMargin:     ThemeClient.metrics.barTopMargin
    readonly property int barExclusiveZone: ThemeClient.metrics.barExclusiveZone
    readonly property int pillHeight:       ThemeClient.metrics.pillHeight
    readonly property int hitTarget:        ThemeClient.metrics.hitTarget

    // Radii
    readonly property int radiusPill:    ThemeClient.metrics.radiusPill
    readonly property int radiusXL:      ThemeClient.metrics.radiusXL
    readonly property int radiusLarge:   ThemeClient.metrics.radiusLarge
    readonly property int radiusMedium:  ThemeClient.metrics.radiusMedium
    readonly property int radiusSmall:   ThemeClient.metrics.radiusSmall
    readonly property int radiusTiny:    ThemeClient.metrics.radiusTiny

    // Spacing
    readonly property int spacingTight:  ThemeClient.metrics.spacingTight
    readonly property int spacingSmall:  ThemeClient.metrics.spacingSmall
    readonly property int spacingNormal: ThemeClient.metrics.spacingNormal
    readonly property int spacingLarge:  ThemeClient.metrics.spacingLarge

    // Font
    readonly property string fontFamily: ThemeClient.fonts.family
    readonly property string fontIcon:   ThemeClient.fonts.icon
    readonly property int fontTiny:   ThemeClient.fonts.tiny
    readonly property int fontSmall:  ThemeClient.fonts.small
    readonly property int fontNormal: ThemeClient.fonts.normal
    readonly property int fontMedium: ThemeClient.fonts.medium
    readonly property int fontLarge:  ThemeClient.fonts.large

    // Animation durations
    readonly property int durFast:   ThemeClient.metrics.durFast
    readonly property int durNormal: ThemeClient.metrics.durNormal
    readonly property int durSlide:  ThemeClient.metrics.durSlide
    readonly property int durEnter:  ThemeClient.metrics.durEnter
    readonly property bool motionEnabled: ThemeClient.metrics.motionEnabled

    // Panel
    readonly property int panelPadding: ThemeClient.metrics.panelPadding
    readonly property int popupGap:     ThemeClient.metrics.popupGap
    readonly property int spacingXL: ThemeClient.metrics.spacingXL
    readonly property real hoverBrightness: ThemeClient.metrics.hoverBrightness
    readonly property real pressScale:      ThemeClient.metrics.pressScale

    // Elevation tiers (see services/theme/ThemeClient elevation group)
    readonly property var elevation: ThemeClient.elevation

    // Ink levels — white-alpha fills on glass (see ThemeClient ink group)
    readonly property var ink: ThemeClient.ink

    // Battery level glyph (Material Design battery ramp), pct 0–100.
    function batteryGlyph(pct) {
        if (pct >= 95) return "󰁹"
        const ramp = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂"]
        return ramp[Math.max(0, Math.min(9, Math.round(pct / 10)))]
    }

    // Launcher
    readonly property int launcherWidth:     ThemeClient.metrics.launcherWidth
    readonly property int launcherMinWidth:  ThemeClient.metrics.launcherMinWidth
    readonly property int launcherMaxHeight: ThemeClient.metrics.launcherMaxHeight
    readonly property int launcherTopMargin: ThemeClient.metrics.launcherTopMargin
    readonly property int searchBarHeight:   ThemeClient.metrics.searchBarHeight
    readonly property int appItemHeight:     ThemeClient.metrics.appItemHeight
    readonly property int resultItemHeight:  ThemeClient.metrics.resultItemHeight
    readonly property int appIconSize:       ThemeClient.metrics.appIconSize
    readonly property int hintBarHeight:     ThemeClient.metrics.hintBarHeight
}
