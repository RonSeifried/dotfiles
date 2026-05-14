import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../.."
import ".."

ColumnLayout {
    id: editor
    property var secrets: []          // [{catalogKey, envName}]
    spacing: Theme.spacingSmall

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingNormal
        Text {
            text: "Secrets"
            color: Colors.text
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontMedium
            font.bold: true
        }
        Text {
            text: editor.secrets.length + " required"
            color: Colors.textMuted
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSmall
        }
        Item { Layout.fillWidth: true }
    }

    Repeater {
        model: editor.secrets

        delegate: Rectangle {
            id: row
            required property var modelData

            readonly property string catalogKey: modelData.catalogKey
            readonly property string envName: modelData.envName
            readonly property bool isSet: McpState.secrets[catalogKey] === true

            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: Theme.radiusSmall
            color: Qt.rgba(Colors.bg.r, Colors.bg.g, Colors.bg.b, 0.4)
            border.color: row.isSet
                ? Qt.rgba(Colors.success.r, Colors.success.g, Colors.success.b, 0.4)
                : Qt.rgba(Colors.warning.r, Colors.warning.g, Colors.warning.b, 0.4)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 6
                spacing: Theme.spacingNormal

                Text {
                    text: row.isSet ? "✓" : "󰌆"
                    color: row.isSet ? Colors.success : Colors.warning
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                }
                ColumnLayout {
                    Layout.preferredWidth: 200
                    spacing: 0
                    Text {
                        text: row.envName
                        color: Colors.text
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSmall
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: row.catalogKey !== row.envName
                        text: row.catalogKey
                        color: Colors.textMuted
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontTiny
                        elide: Text.ElideMiddle
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    radius: Theme.radiusPill
                    color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, 0.7)
                    border.color: valueField.activeFocus
                        ? Colors.accent
                        : Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.15)
                    border.width: 1

                    TextField {
                        id: valueField
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        background: null
                        echoMode: TextInput.Password
                        placeholderText: row.isSet ? "•••••• (set — type to replace)" : "Paste secret value…"
                        placeholderTextColor: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.35)
                        color: Colors.text
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSmall
                        verticalAlignment: TextInput.AlignVCenter
                        inputMethodHints: Qt.ImhSensitiveData
                        onAccepted: {
                            if (text.length > 0) {
                                McpState.setSecret(row.catalogKey, text)
                                text = ""
                            }
                        }
                    }
                }

                // Save button
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: Theme.radiusMedium
                    enabled: valueField.text.length > 0 && !McpState.busy
                    opacity: enabled ? 1 : 0.35
                    color: saveHover.containsMouse && enabled
                        ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 1.0)
                        : Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.85)
                    Text {
                        anchors.centerIn: parent
                        text: "󰆓"
                        color: Colors.bg
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                    }
                    MouseArea {
                        id: saveHover
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: parent.enabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            McpState.setSecret(row.catalogKey, valueField.text)
                            valueField.text = ""
                        }
                    }
                }

                // Remove button
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: Theme.radiusMedium
                    visible: row.isSet
                    enabled: !McpState.busy
                    opacity: enabled ? 1 : 0.35
                    color: rmHover.containsMouse
                        ? Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.25)
                        : Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.10)
                    border.color: Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.45)
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "󰆴"
                        color: Colors.error
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }
                    MouseArea {
                        id: rmHover
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: parent.enabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: McpState.removeSecret(row.catalogKey)
                    }
                }
            }
        }
    }
}
