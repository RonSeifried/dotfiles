import QtQuick
import "../.."

Column {
    id: root
    width: parent ? parent.width : 0
    spacing: Theme.spacingSmall

    Repeater {
        model: FocusState.scenes
        delegate: Rectangle {
            id: scene
            required property var modelData
            width: root.width; height: 52; radius: Theme.radiusMedium
            color: FocusState.activeScene === modelData.id
                ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.16)
                : sceneHover.containsMouse ? Qt.rgba(1, 1, 1, Theme.hoverBrightness)
                : Qt.rgba(1, 1, 1, 0.045)
            Row {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                spacing: Theme.spacingNormal
                Text {
                    text: scene.modelData.icon
                    color: FocusState.activeScene === scene.modelData.id ? Colors.accent : Colors.textMuted
                    font.pixelSize: Theme.fontLarge; font.family: Theme.fontIcon
                    anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                    width: parent.width - 54; spacing: 1
                    Text { text: scene.modelData.label; color: Colors.text; font.pixelSize: Theme.fontNormal; font.family: Theme.fontFamily }
                    Text { text: scene.modelData.detail; color: Colors.textMuted; font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily }
                }
                Text {
                    visible: FocusState.activeScene === scene.modelData.id
                    text: "󰄬"; color: Colors.accent
                    font.pixelSize: Theme.fontMedium; font.family: Theme.fontIcon
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MouseArea {
                id: sceneHover; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: FocusState.apply(scene.modelData.id)
            }
        }
    }

    Rectangle {
        width: parent.width; height: 36; radius: Theme.radiusMedium
        visible: FocusState.activeScene !== "off"
        color: offHover.containsMouse ? Qt.rgba(1, 1, 1, Theme.hoverBrightness) : Qt.rgba(1, 1, 1, 0.045)
        Text { anchors.centerIn: parent; text: "Turn Focus Off"; color: Colors.text; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily }
        MouseArea { id: offHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: FocusState.apply("off") }
    }
}
