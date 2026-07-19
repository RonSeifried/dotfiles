import QtQuick
import ".."
import QtQuick.Layouts
import Quickshell


RowLayout {
    id: root
    spacing: 4

    // Show only workspaces belonging to this bar's screen.
    property string output: ""

    Repeater {
        model: root.output
            ? WMState.workspaces.filter(w => w.output === root.output)
            : WMState.workspaces

        delegate: Rectangle {
            required property var modelData
            property bool isActive: modelData.id === WMState.activeWorkspaceId
            property bool hasWindows: modelData.windows_count > 0
            property bool isUrgent: modelData.is_urgent === true

            implicitWidth: wsLabel.implicitWidth + 16
            implicitHeight: Theme.pillHeight
            radius: Theme.radiusSmall

            color: isActive
                ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.52)
                : hoverArea.containsMouse
                    ? Qt.rgba(1, 1, 1, Theme.hoverBrightness * 0.75)
                : "transparent"
            border.width: isActive ? 1 : 0
            border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.82)

            Behavior on color {
                ColorAnimation { duration: 120 }
            }

            Behavior on implicitWidth {
                NumberAnimation { duration: 130; easing.type: Easing.OutQuad }
            }

            Rectangle {
                id: urgentOverlay
                anchors.fill: parent
                radius: parent.radius
                // Urgency is a SIGNAL, not chrome — error, not accent, so a
                // blinking urgent pill can't be mistaken for the active one.
                color: Colors.error
                visible: parent.isUrgent && !parent.isActive
                opacity: Theme.motionEnabled ? 0 : 0.55

                SequentialAnimation on opacity {
                    running: urgentOverlay.visible && Theme.motionEnabled
                    loops: Animation.Infinite
                    NumberAnimation { from: 0; to: 0.55; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.55; to: 0; duration: 600; easing.type: Easing.InOutSine }
                }
            }

            Text {
                id: wsLabel
                anchors.centerIn: parent
                text: modelData.name || String(modelData.idx)
                color: parent.isActive ? Colors.text : Colors.textMuted
                font.pixelSize: Theme.fontMedium
                font.family: Theme.fontFamily
                z: 1

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }
            }

            // dot indicator for non-active workspaces with windows
            Rectangle {
                visible: !parent.isActive && parent.hasWindows && !parent.isUrgent
                width: 4; height: 4; radius: 2
                color: Colors.accent
                z: 1
                anchors { bottom: parent.bottom; bottomMargin: 2; horizontalCenter: parent.horizontalCenter }
            }

            MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: WMState.focusWorkspace(parent.modelData.id)
            }

            Accessible.role: Accessible.Button
            Accessible.name: "Workspace " + (modelData.name || String(modelData.idx))
        }
    }
}
