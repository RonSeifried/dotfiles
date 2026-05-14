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
            implicitHeight: 22
            radius: 999

            color: isActive
                ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.55)
                : (hoverArea.containsMouse
                    ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.pillHoverAlpha)
                    : "transparent")

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
                color: Colors.accent
                visible: parent.isUrgent && !parent.isActive
                opacity: 0

                SequentialAnimation on opacity {
                    running: urgentOverlay.visible
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
        }
    }
}
