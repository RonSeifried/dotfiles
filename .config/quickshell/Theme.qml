pragma Singleton
import QtQuick

QtObject {
    // ── Sizes ────────────────────────────────────────────────────
    readonly property int barHeight:        36
    readonly property int barMargin:        8
    readonly property int barTopMargin:     6
    readonly property int barExclusiveZone: 42
    readonly property int pillHeight:       28

    // ── Radii ────────────────────────────────────────────────────
    readonly property int radiusPill:    999
    readonly property int radiusLarge:   14
    readonly property int radiusMedium:  12
    readonly property int radiusSmall:   8
    readonly property int radiusTiny:    6

    // ── Spacing ──────────────────────────────────────────────────
    readonly property int spacingTight:  4
    readonly property int spacingSmall:  6
    readonly property int spacingNormal: 8
    readonly property int spacingLarge:  12

    // ── Font ─────────────────────────────────────────────────────
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int fontTiny:   9
    readonly property int fontSmall:  10
    readonly property int fontNormal: 11
    readonly property int fontMedium: 12
    readonly property int fontLarge:  13

    // ── Animation durations ──────────────────────────────────────
    readonly property int durFast:     120
    readonly property int durNormal:   180
    readonly property int durSlide:    220
    readonly property int durHover:    150
    readonly property int durColor:    380

    // ── Panel ────────────────────────────────────────────────────
    readonly property int panelPadding: 10
    readonly property int popupGap:     4

    // ── Launcher ─────────────────────────────────────────────────
    readonly property int launcherWidth:      440
    readonly property int launcherMaxHeight:  480
    readonly property int launcherTopMargin:  100
    readonly property int searchBarHeight:    40
    readonly property int appItemHeight:      38
    readonly property int resultItemHeight:   46
    readonly property int appIconSize:        22
    readonly property int hintBarHeight:      22
}
