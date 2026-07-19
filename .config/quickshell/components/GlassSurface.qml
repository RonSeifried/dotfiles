import QtQuick
import ".."
import "../services/theme/lib/palette.js" as Palette

// Liquid-glass base material. Tint over bgVariant + white top-edge highlight
// + accent hairline border, picked from an elevation tier. Native compositor
// blur is owned by the WINDOW (PopupWindow/PanelWindow) that hosts this, not
// here — see RightPanelPopup for the blurRegion pattern. This draws only the
// glass fill/edges on top of that blur.
//
// Layer order is fill → content → edges, so the glass edges always stay crisp
// on top of content. Children declared inline become the content layer
// (default property).
Item {
    id: root

    // level selects the ELEVATION (alpha intensity): "e1" flush/low (pills),
    // "e2" raised (popups/cards), "e3" floating (launcher/modal).
    property string level: "e2"
    property int radius: Theme.radiusMedium
    // Per-corner radii default to `radius`. Override individually for surfaces
    // that join another element — e.g. a popup hanging off a bar pill sets the
    // top corners to 0 so it meets the pill squarely.
    property int topLeftRadius: radius
    property int topRightRadius: radius
    property int bottomLeftRadius: radius
    property int bottomRightRadius: radius
    property bool interactive: false
    property string accessibleName: ""
    property string accessibleDescription: ""
    // Frost material (macOS-26): a LIGHT, white-tinted frosted surface instead
    // of the dark bgVariant glass — for tiles/cards that should read as bright
    // panes floating on the darker panel. Border becomes a neutral white edge
    // (no accent outline), matching macOS control tiles.
    property bool frost: false
    property real frostAlpha: Palette.frost.fill   // shared with lock (palette.js)
    // Edge control. "top" toggles the white highlight line; "left"/"right"/
    // "bottom" toggle accent hairlines. Popups joined to a pill omit "top".
    property var edges: ["top", "right", "bottom", "left"]

    default property alias content: contentHolder.data
    signal clicked()

    activeFocusOnTab: interactive
    Accessible.role: interactive ? Accessible.Button : Accessible.Pane
    Accessible.name: accessibleName
    Accessible.description: accessibleDescription
    Keys.onReturnPressed: if (interactive) root.clicked()
    Keys.onEnterPressed: if (interactive) root.clicked()
    Keys.onSpacePressed: if (interactive) root.clicked()

    // ── level → elevation alpha lookup ───────────────────────────
    readonly property real _tintAlpha: level === "e1" ? Theme.elevation.e1TintAlpha
        : level === "e3" ? Theme.elevation.e3TintAlpha : Theme.elevation.e2TintAlpha
    readonly property real _highlightAlpha: level === "e1" ? Theme.elevation.e1HighlightAlpha
        : level === "e3" ? Theme.elevation.e3HighlightAlpha : Theme.elevation.e2HighlightAlpha
    readonly property real _borderAlpha: level === "e1" ? Theme.elevation.e1BorderAlpha
        : level === "e3" ? Theme.elevation.e3BorderAlpha : Theme.elevation.e2BorderAlpha
    readonly property color _tintColor: Colors.bgVariant
    // Fill: frost → white wash; otherwise the tinted glass.
    // (A former "prominent" accent-tinted tier was never used — state lives
    // in badges/toggles, never in the surface fill. Removed as dead code.)
    readonly property color _fillColor: frost
        ? Qt.rgba(1, 1, 1, frostAlpha)
        : Qt.rgba(_tintColor.r, _tintColor.g, _tintColor.b, _tintAlpha)
    // Chrome edges are neutral. Accent belongs to selection and live state,
    // never to every perimeter on screen.
    readonly property color _borderColor: Qt.rgba(1, 1, 1,
        frost ? Palette.frost.border : _borderAlpha)

    // Auto-size to content. childrenRect aggregates children placed in
    // contentHolder; consumers that want a fixed size override these (or set
    // width/height). Non-circular as long as content children are not
    // fill-anchored to contentHolder.
    implicitWidth: contentHolder.childrenRect.width
    implicitHeight: contentHolder.childrenRect.height

    // Press-scale feedback (interactive only).
    scale: interactive && _press.pressed ? Theme.pressScale : 1.0
    Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }

    // ── fill (bottom layer) ──────────────────────────────────────
    Rectangle {
        id: fill
        anchors.fill: parent
        topLeftRadius: root.topLeftRadius; topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius; bottomRightRadius: root.bottomRightRadius
        color: root._fillColor
        border.width: 1
        border.color: root._borderColor
        // Smooth the tier/level transition (e.g. a tile toggling on/off).
        Behavior on color { ColorAnimation { duration: Theme.durNormal; easing.type: Easing.OutCubic } }
        // Hover-brightness: a white overlay at hoverBrightness alpha.
        Rectangle {
            anchors.fill: parent
            topLeftRadius: parent.topLeftRadius; topRightRadius: parent.topRightRadius
            bottomLeftRadius: parent.bottomLeftRadius; bottomRightRadius: parent.bottomRightRadius
            color: "white"
            opacity: root.interactive && _hover.hovered ? Theme.hoverBrightness : 0.0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
        }
    }

    // Keyboard focus is deliberately neutral-white: accent remains reserved
    // for selection/state instead of doing three jobs at once.
    Rectangle {
        anchors.fill: parent
        topLeftRadius: root.topLeftRadius; topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius; bottomRightRadius: root.bottomRightRadius
        color: "transparent"
        border.width: root.activeFocus ? 2 : 0
        border.color: Qt.rgba(1, 1, 1, 0.72)
        z: 10
    }

    // ── content (middle layer) ───────────────────────────────────
    Item {
        id: contentHolder
        anchors.fill: parent
    }

    // QtQuick.Shape's curve renderer corrupted shared layer-shell textures on
    // some GPUs, producing diagonal lines across unrelated windows. The native
    // rounded Rectangle border is stable and follows all per-corner radii.

    // Top-edge white highlight (the "light from above").
    Rectangle {
        visible: root.edges.indexOf("top") !== -1
        anchors { left: parent.left; right: parent.right; top: parent.top }
        anchors.leftMargin: root.topLeftRadius
        anchors.rightMargin: root.topRightRadius
        height: 1
        color: Qt.rgba(1, 1, 1, root._highlightAlpha)
    }

    HoverHandler { id: _hover; enabled: root.interactive }
    // TapHandler exposes `pressed` for the press-scale; emits clicked upward.
    TapHandler { id: _press; enabled: root.interactive; onTapped: root.clicked() }
}
