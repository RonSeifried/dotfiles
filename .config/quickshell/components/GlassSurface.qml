import QtQuick
import QtQuick.Shapes
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
    // Per-corner radii default to `radius`. Override individually for surfaces
    // that join another element — e.g. a popup hanging off a bar pill sets the
    // top corners to 0 so it meets the pill squarely.
    property int topLeftRadius: radius
    property int topRightRadius: radius
    property int bottomLeftRadius: radius
    property int bottomRightRadius: radius
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
        topLeftRadius: root.topLeftRadius; topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius; bottomRightRadius: root.bottomRightRadius
        color: Qt.rgba(root._tintColor.r, root._tintColor.g, root._tintColor.b, root._tintAlpha)
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

    // ── content (middle layer) ───────────────────────────────────
    Item {
        id: contentHolder
        anchors.fill: parent
    }

    // ── edges (top layer — drawn over content so they stay crisp) ─
    // Accent hairline tracing left side → bottom corners → right side, following
    // the rounded corners. A Shape stroke is used because straight inset
    // Rectangles can't trace the corner arc and Rectangle.border does not render
    // with per-corner radii in this Qt build. The top edge is intentionally not
    // stroked — it carries the white highlight instead (or is omitted for
    // pill-joined surfaces). 0.5px inset keeps the 1px stroke inside the bounds.
    // SVG outline at 0.5px inset (keeps the 1px stroke inside the bounds).
    // Top present → CLOSED rounded rect tracing all four corners. Top omitted
    // (pill-join) → OPEN path (left + bottom corners + right), top left bare so
    // the surface meets the pill. Quadratic corners (Q) avoid arc-direction bugs.
    readonly property bool _omitTop: edges.indexOf("top") === -1
    readonly property string _pathData: {
        const x0 = 0.5, y0 = 0.5, x1 = width - 0.5, y1 = height - 0.5
        const tl = topLeftRadius, tr = topRightRadius, bl = bottomLeftRadius, br = bottomRightRadius
        const sides =
            `L ${x1},${y1 - br} Q ${x1},${y1} ${x1 - br},${y1} ` +   // right + BR
            `L ${x0 + bl},${y1} Q ${x0},${y1} ${x0},${y1 - bl} `     // bottom + BL
        if (_omitTop)
            return `M ${x0},${y0} L ${x0},${y1 - bl} Q ${x0},${y1} ${x0 + bl},${y1} ` +
                   `L ${x1 - br},${y1} Q ${x1},${y1} ${x1},${y1 - br} L ${x1},${y0}`
        return `M ${x0 + tl},${y0} L ${x1 - tr},${y0} Q ${x1},${y0} ${x1},${y0 + tr} ` +
               sides + `L ${x0},${y0 + tl} Q ${x0},${y0} ${x0 + tl},${y0} Z`
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root._borderColor
            strokeWidth: 1
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root._pathData }
        }
    }

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
