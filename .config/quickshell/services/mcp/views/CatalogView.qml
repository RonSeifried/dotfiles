import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../.."
import ".."

Item {
    id: view
    signal showDetail(string name)

    property string filter: ""
    property var filtered: McpState.catalog.filter(c =>
        filter === "" || c.name.toLowerCase().includes(filter.toLowerCase()))

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingLarge

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingLarge

            Text {
                text: "Catalog"
                color: Colors.text
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontLarge
                font.bold: true
            }
            Text {
                text: McpState.catalog.length + " servers"
                color: Colors.textMuted
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSmall
            }
            Item { Layout.fillWidth: true }
            // Filter input
            Rectangle {
                Layout.preferredWidth: 240
                Layout.preferredHeight: 28
                radius: Theme.radiusPill
                color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, 0.5)
                border.color: filterField.activeFocus
                    ? Colors.accent
                    : Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.15)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 6
                    Text {
                        text: "󰍉"
                        color: Colors.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }
                    TextField {
                        id: filterField
                        Layout.fillWidth: true
                        background: null
                        placeholderText: "Filter…"
                        placeholderTextColor: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.4)
                        color: Colors.text
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSmall
                        onTextChanged: view.filter = text
                    }
                }
            }
        }

        // Empty / loading
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: McpState.catalog.length === 0

            Text {
                anchors.centerIn: parent
                text: McpState.loadingCatalog ? "Loading catalog…" : "No catalog entries."
                color: Colors.textMuted
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontMedium
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: McpState.catalog.length > 0
            clip: true
            model: view.filtered
            spacing: Theme.spacingSmall
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width
                height: 64
                radius: Theme.radiusMedium
                color: hover.containsMouse
                    ? Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.04)
                    : "transparent"
                border.width: 1
                border.color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.08)
                Behavior on color { ColorAnimation { duration: Theme.durFast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingLarge
                    anchors.rightMargin: Theme.spacingLarge
                    spacing: Theme.spacingLarge

                    Text {
                        text: "󰏗"
                        color: Colors.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 18
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            text: modelData.name
                            color: Colors.text
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontMedium
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: modelData.description !== ""
                            text: modelData.description
                            color: Colors.textMuted
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontTiny
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }
                    // Enabled badge
                    Rectangle {
                        visible: McpState.servers.some(s => s.name === modelData.name)
                        Layout.preferredHeight: 22
                        Layout.preferredWidth: enabledLabel.implicitWidth + 16
                        radius: Theme.radiusPill
                        color: Qt.rgba(Colors.success.r, Colors.success.g, Colors.success.b, 0.18)
                        Text {
                            id: enabledLabel
                            anchors.centerIn: parent
                            text: "enabled"
                            color: Colors.success
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontTiny
                            font.bold: true
                        }
                    }
                    // Inspect button
                    Rectangle {
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: 36
                        radius: Theme.radiusMedium
                        color: inspectHover.containsMouse
                            ? Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.10)
                            : "transparent"
                        border.color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.18)
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "󰋼"
                            color: Colors.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                        }
                        MouseArea {
                            id: inspectHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.showDetail(modelData.name)
                        }
                    }
                    // Enable button
                    Rectangle {
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: 92
                        radius: Theme.radiusMedium
                        property bool already: McpState.servers.some(s => s.name === modelData.name)
                        enabled: !already && !McpState.busy
                        opacity: enabled ? 1 : 0.45
                        color: enableHover.containsMouse && enabled
                            ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 1.0)
                            : Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.85)
                        Text {
                            anchors.centerIn: parent
                            text: parent.already ? "Enabled" : "Enable"
                            color: Colors.bg
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSmall
                            font.bold: true
                        }
                        MouseArea {
                            id: enableHover
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: parent.enabled
                            cursorShape: Qt.PointingHandCursor
                            onClicked: McpState.enableServer(modelData.name)
                        }
                    }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }
            }
        }
    }
}
