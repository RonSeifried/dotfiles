import QtQuick
import ".."

// Bar cluster icon button. Centralizes hover/click + pin behavior.
//
// Hover  → set rightPanel + activeScreen (no pin change).
// Click  → if THIS panel is pinned: unpin + close.
//          else: pin this panel (replaces any prior pin).
//
// Pin is scoped per-panel via bar.pinnedPanel (string), so hovering a
// different pill while another panel is pinned does NOT make the hovered
// one pinned. closeTimer in popups uses pinnedPanel===rightPanel match.
//
// Children declared inside default property become the icon content.
Item {
    id: root

    // Target panel name ("wifi" | "audio" | …) consumed by RightPanelPopup loader.
    required property string panel

    // The owning Bar PanelWindow — used for screen + pinnedPanel toggling.
    required property var bar

    // Use `data` (not `children`) so non-visual elements (FileView, Timer, …)
    // declared inline are routed to resources and don't error.
    default property alias contentChildren: contentRow.data
    property real horizontalPadding: 0

    // When true, the pill does NOT drive ControlState.rightPanel on hover/click;
    // hovering does nothing and clicking emits activated() instead.
    property bool clickOnly: false
    signal activated()

    // Wheel passthrough — connect to handle scroll on the pill (e.g. audio volume).
    signal wheelEvent(var event)

    implicitWidth: contentRow.implicitWidth + 2 * horizontalPadding
    implicitHeight: contentRow.implicitHeight

    Row {
        id: contentRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: root.horizontalPadding
    }

    HoverHandler {
        onHoveredChanged: if (hovered) {
            if (!root.clickOnly) {
                ControlState.activeScreen = root.bar.screen.name
                ControlState.rightPanel = root.panel
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.clickOnly) { root.activated(); return }
            if (root.bar.pinnedPanel === root.panel) {
                root.bar.pinnedPanel = ""
                ControlState.rightPanel = "none"
            } else {
                ControlState.activeScreen = root.bar.screen.name
                ControlState.rightPanel = root.panel
                root.bar.pinnedPanel = root.panel
            }
        }
        onWheel: ev => root.wheelEvent(ev)
    }
}
