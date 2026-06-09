import QtQuick
import ".."

// Right-cluster entry that opens the Control Center. Tappable glyph, tinted
// accent while the CC is open.
Item {
    id: root
    required property var bar
    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    Text {
        id: icon
        text: "󰕮"
        color: ControlState.controlCenterOpen ? Colors.accent : Colors.text
        font.pixelSize: Theme.fontLarge
        font.family: Theme.fontFamily
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (ControlState.controlCenterOpen) { ControlState.closeControlCenter(); return }
            ControlState.activeScreen = root.bar.screen.name
            ControlState.openControlCenter("")
        }
    }
}
