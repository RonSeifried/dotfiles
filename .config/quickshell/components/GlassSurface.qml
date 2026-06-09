import QtQuick
import ".."

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

    // tier selects the TINT COLOR: "regular" = neutral bgVariant,
    // "prominent" = accent-tinted (primary actions / active state).
    property string tier: "regular"
    // level selects the ELEVATION (alpha intensity): "e1" flush/low (pills),
    // "e2" raised (popups/cards), "e3" floating (launcher/modal).
    property string level: "e2"
    property int radius: Theme.radiusMedium
    property bool interactive: false
    // Edge control. "top" toggles the white highlight line; "left"/"right"/
    // "bottom" toggle accent hairlines. Popups joined to a pill omit "top".
    property var edges: ["top", "right", "bottom", "left"]

    default property alias content: contentHolder.data
    signal clicked()

    // ── level → elevation alpha lookup ───────────────────────────
    readonly property real _tintAlpha: level === "e1" ? Theme.elevation.e1TintAlpha
        : level === "e3" ? Theme.elevation.e3TintAlpha : Theme.elevation.e2TintAlpha
    readonly property real _highlightAlpha: level === "e1" ? Theme.elevation.e1HighlightAlpha
        : level === "e3" ? Theme.elevation.e3HighlightAlpha : Theme.elevation.e2HighlightAlpha
    readonly property real _borderAlpha: level === "e1" ? Theme.elevation.e1BorderAlpha
        : level === "e3" ? Theme.elevation.e3BorderAlpha : Theme.elevation.e2BorderAlpha
    readonly property color _tintColor: tier === "prominent" ? Colors.accent : Colors.bgVariant
    readonly property color _borderColor: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, _borderAlpha)

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
        radius: root.radius
        color: Qt.rgba(root._tintColor.r, root._tintColor.g, root._tintColor.b, root._tintAlpha)
        // Hover-brightness: a white overlay at hoverBrightness alpha.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "white"
            opacity: root.interactive && _hover.hovered ? Theme.hoverBrightness : 0.0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
        }
    }

    // ── content (middle layer) ───────────────────────────────────
    Item {
        id: contentHolder
        anchors.fill: parent
    }

    // ── edges (top layer — drawn over content so they stay crisp) ─
    // Top-edge highlight (the "light from above").
    Rectangle {
        visible: root.edges.indexOf("top") !== -1
        anchors { left: parent.left; right: parent.right; top: parent.top }
        anchors.leftMargin: root.radius
        anchors.rightMargin: root.radius
        height: 1
        color: Qt.rgba(1, 1, 1, root._highlightAlpha)
    }
    // Left
    Rectangle {
        visible: root.edges.indexOf("left") !== -1
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        anchors.topMargin: root.radius; anchors.bottomMargin: root.radius
        width: 1
        color: root._borderColor
    }
    // Right
    Rectangle {
        visible: root.edges.indexOf("right") !== -1
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        anchors.topMargin: root.radius; anchors.bottomMargin: root.radius
        width: 1
        color: root._borderColor
    }
    // Bottom
    Rectangle {
        visible: root.edges.indexOf("bottom") !== -1
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        anchors.leftMargin: root.radius; anchors.rightMargin: root.radius
        height: 1
        color: root._borderColor
    }

    HoverHandler { id: _hover; enabled: root.interactive }
    // TapHandler exposes `pressed` for the press-scale; emits clicked upward.
    TapHandler { id: _press; enabled: root.interactive; onTapped: root.clicked() }
}
