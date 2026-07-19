import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../.."
import ".."

Item {
    id: view

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingLarge

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Clients"
                color: Colors.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLarge
                font.bold: true
            }
            Text {
                text: McpState.clients.filter(c => c.connected).length
                    + " / " + McpState.clients.length + " connected"
                color: Colors.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
            }
            Item { Layout.fillWidth: true }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Theme.spacingSmall
            model: McpState.clients
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width
                height: 48
                radius: Theme.radiusMedium
                color: rowHover.containsMouse
                    ? Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.04)
                    : "transparent"
                border.width: 1
                border.color: modelData.connected
                    ? Qt.rgba(Colors.success.r, Colors.success.g, Colors.success.b, 0.35)
                    : Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.10)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingLarge
                    anchors.rightMargin: Theme.spacingLarge
                    spacing: Theme.spacingLarge

                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: modelData.connected ? Colors.success : Qt.rgba(Colors.textMuted.r, Colors.textMuted.g, Colors.textMuted.b, 0.6)
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.name
                        color: Colors.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontMedium
                        elide: Text.ElideRight
                    }
                    Text {
                        text: modelData.connected ? "connected" : "disconnected"
                        color: modelData.connected ? Colors.success : Colors.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTiny
                    }

                    Rectangle {
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: 110
                        radius: Theme.radiusMedium
                        enabled: !McpState.busy
                        opacity: enabled ? 1 : 0.4
                        color: modelData.connected
                            ? (btnHover.containsMouse
                                ? Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.25)
                                : Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.10))
                            : (btnHover.containsMouse
                                ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 1.0)
                                : Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.85))
                        border.color: modelData.connected
                            ? Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.45)
                            : "transparent"
                        border.width: modelData.connected ? 1 : 0
                        Text {
                            anchors.centerIn: parent
                            text: modelData.connected ? "Disconnect" : "Connect"
                            color: modelData.connected ? Colors.error : Colors.bg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            font.bold: true
                        }
                        MouseArea {
                            id: btnHover
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: parent.enabled
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.connected) McpState.disconnectClient(modelData.name)
                                else                    McpState.connectClient(modelData.name)
                            }
                        }
                    }
                }

                MouseArea {
                    id: rowHover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }
            }
        }
    }
}
