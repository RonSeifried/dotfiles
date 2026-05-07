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
            ? NiriState.workspaces.filter(w => w.output === root.output)
            : NiriState.workspaces

        delegate: Rectangle {
            required property var modelData
            property bool isActive: modelData.id === NiriState.activeWorkspaceId
            property bool hasWindows: modelData.windows_count > 0

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

            Text {
                id: wsLabel
                anchors.centerIn: parent
                text: modelData.name || String(modelData.idx)
                color: parent.isActive ? Colors.text : Colors.textMuted
                font.pixelSize: 12
                font.family: "JetBrainsMono Nerd Font"

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }
            }

            // dot indicator for non-active workspaces with windows
            Rectangle {
                visible: !parent.isActive && parent.hasWindows
                width: 4; height: 4; radius: 2
                color: Colors.accent
                anchors { bottom: parent.bottom; bottomMargin: 2; horizontalCenter: parent.horizontalCenter }
            }

            MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: NiriState.focusWorkspace(parent.modelData.id)
            }
        }
    }
}
