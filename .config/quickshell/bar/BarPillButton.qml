import QtQuick
import ".."

// Bar cluster icon button: hover chip + click → activated(). The old
// hover-opens-panel / pin machinery died with RightPanelPopup — every bar
// pill now opens the Control Center (or acts directly) on click.
//
// Children declared inside default property become the icon content.
Item {
    id: root

    signal activated()

    // Wheel passthrough — connect to handle scroll on the pill (e.g. audio volume).
    signal wheelEvent(var event)
    property string accessibleName: ""

    // Use `data` (not `children`) so non-visual elements (FileView, Timer, …)
    // declared inline are routed to resources and don't error.
    default property alias contentChildren: contentRow.data
    // Horizontal breathing room around the glyph — also the hover chip's padding.
    property real horizontalPadding: 7

    readonly property alias hovered: _hover.hovered

    implicitWidth: contentRow.implicitWidth + 2 * horizontalPadding
    implicitHeight: Theme.hitTarget
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: accessibleName
    Keys.onReturnPressed: root.activated()
    Keys.onEnterPressed: root.activated()
    Keys.onSpacePressed: root.activated()

    // macOS-style hover chip: a subtle rounded highlight, no permanent chrome.
    Rectangle {
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: Theme.pillHeight
        radius: Theme.radiusSmall
        color: Qt.rgba(1, 1, 1, _hover.hovered ? Theme.hoverBrightness : 0)
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
    }

    HoverHandler { id: _hover }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
        onWheel: ev => root.wheelEvent(ev)
    }


    Rectangle {
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: Theme.pillHeight; radius: Theme.radiusSmall; color: "transparent"
        border.width: root.activeFocus ? 2 : 0
        border.color: Qt.rgba(1, 1, 1, 0.72)
    }
}
