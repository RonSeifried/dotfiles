import QtQuick
import ".."
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Row {
    id: root
    spacing: Theme.spacingNormal

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: trayItem
            required property SystemTrayItem modelData
            implicitWidth: 16
            implicitHeight: 16

            IconImage {
                anchors.fill: parent
                source: trayItem.modelData.icon
                opacity: trayItem.modelData.status === Status.Passive ? 0.5 : 1.0
            }

            MouseArea {
                id: trayMouse
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: ev => {
                    if (ev.button === Qt.LeftButton) {
                        if (trayItem.modelData.onlyMenu) menuAnchor.open()
                        else trayItem.modelData.activate()
                    } else if (ev.button === Qt.RightButton) {
                        if (trayItem.modelData.hasMenu) menuAnchor.open()
                    } else if (ev.button === Qt.MiddleButton) {
                        trayItem.modelData.secondaryActivate()
                    }
                }
                onWheel: ev => {
                    trayItem.modelData.scroll(ev.angleDelta.y, false)
                    ev.accepted = true
                }
            }

            QsMenuAnchor {
                id: menuAnchor
                menu: trayItem.modelData.menu
                anchor.item: trayItem
                anchor.edges: Edges.Bottom
                anchor.gravity: Edges.Bottom
            }
        }
    }
}
