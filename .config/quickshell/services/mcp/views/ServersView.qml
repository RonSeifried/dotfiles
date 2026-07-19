import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../.."
import ".."

Item {
    id: view
    signal showDetail(string name)

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingLarge

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingLarge
            Text {
                text: "Enabled Servers"
                color: Colors.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLarge
                font.bold: true
            }
            Text {
                text: McpState.servers.length + " enabled"
                color: Colors.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
            }
            Item { Layout.fillWidth: true }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: McpState.servers.length === 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Theme.spacingNormal
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: McpState.loadingServers ? "Loading…" : "No servers enabled."
                    color: Colors.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontMedium
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: !McpState.loadingServers
                    text: "Browse the catalog to enable one."
                    color: Colors.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                }
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: McpState.servers.length > 0
            clip: true
            spacing: Theme.spacingSmall
            model: McpState.servers
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width
                height: 56
                radius: Theme.radiusMedium
                color: rowHover.containsMouse
                    ? Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.04)
                    : "transparent"
                border.width: 1
                border.color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.08)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingLarge
                    anchors.rightMargin: Theme.spacingLarge
                    spacing: Theme.spacingLarge

                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: Colors.success
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.name
                        color: Colors.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontMedium
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    // Inspect
                    Rectangle {
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: 80
                        radius: Theme.radiusMedium
                        color: inspectHover.containsMouse
                            ? Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.10)
                            : "transparent"
                        border.color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.20)
                        border.width: 1
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "󰋼"
                                color: Colors.text
                                font.family: Theme.fontIcon
                                font.pixelSize: 13
                            }
                            Text {
                                text: "Inspect"
                                color: Colors.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                            }
                        }
                        MouseArea {
                            id: inspectHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.showDetail(modelData.name)
                        }
                    }

                    // Disable
                    Rectangle {
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: 80
                        radius: Theme.radiusMedium
                        enabled: !McpState.busy
                        opacity: enabled ? 1 : 0.45
                        color: disableHover.containsMouse
                            ? Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.22)
                            : Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.10)
                        border.color: Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.45)
                        border.width: 1
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "󰓛"
                                color: Colors.error
                                font.family: Theme.fontIcon
                                font.pixelSize: 13
                            }
                            Text {
                                text: "Disable"
                                color: Colors.error
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                                font.bold: true
                            }
                        }
                        MouseArea {
                            id: disableHover
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: parent.enabled
                            cursorShape: Qt.PointingHandCursor
                            onClicked: McpState.disableServer(modelData.name)
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
