import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../.."
import ".."

Item {
    id: view
    signal back()

    readonly property string name: McpState.currentInspect
    readonly property var detailData: McpState.inspectCache[name] || null
    readonly property bool ready: detailData !== null

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingLarge

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingNormal

            Rectangle {
                Layout.preferredHeight: 28
                Layout.preferredWidth: 28
                radius: Theme.radiusMedium
                color: backHover.containsMouse
                    ? Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.10)
                    : "transparent"
                border.color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.20)
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "󰁍"
                    color: Colors.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                }
                MouseArea {
                    id: backHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.back()
                }
            }

            Text {
                text: view.name
                color: Colors.text
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontLarge
                font.bold: true
            }
            Text {
                visible: McpState.servers.some(s => s.name === view.name)
                text: "● enabled"
                color: Colors.success
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSmall
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                Layout.preferredHeight: 28
                Layout.preferredWidth: 80
                radius: Theme.radiusMedium
                color: refreshHover.containsMouse
                    ? Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.10)
                    : "transparent"
                border.color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.20)
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: McpState.loadingInspect ? "loading…" : "Refresh"
                    color: Colors.text
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSmall
                }
                MouseArea {
                    id: refreshHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: McpState.inspectServer(view.name, true)
                }
            }
        }

        // Loading placeholder
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !view.ready

            Text {
                anchors.centerIn: parent
                text: McpState.loadingInspect ? "Loading…" : "—"
                color: Colors.textMuted
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontMedium
            }
        }

        // Detail body
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: view.ready
            clip: true

            ColumnLayout {
                width: view.width
                spacing: Theme.spacingLarge

                // Meta card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: metaCol.implicitHeight + 24
                    radius: Theme.radiusMedium
                    color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, 0.5)
                    border.color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.10)
                    border.width: 1

                    ColumnLayout {
                        id: metaCol
                        anchors {
                            left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                            leftMargin: 16; rightMargin: 16
                        }
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            visible: view.ready && view.detailData.description !== ""
                            text: view.detailData ? view.detailData.description : ""
                            color: Colors.text
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontMedium
                            wrapMode: Text.WordWrap
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 18
                            visible: view.ready

                            Text {
                                visible: view.detailData && view.detailData.author
                                text: "Author: " + (view.detailData ? view.detailData.author : "")
                                color: Colors.textMuted
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontTiny
                            }
                            Text {
                                visible: view.detailData && view.detailData.license
                                text: "License: " + (view.detailData ? view.detailData.license : "")
                                color: Colors.textMuted
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontTiny
                            }
                            Item { Layout.fillWidth: true }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: view.ready && view.detailData && view.detailData.repo
                            text: view.detailData ? view.detailData.repo : ""
                            color: Colors.accent
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontTiny
                            elide: Text.ElideRight
                        }
                    }
                }

                // Secrets editor
                Rectangle {
                    Layout.fillWidth: true
                    visible: view.ready && view.detailData.secrets && view.detailData.secrets.length > 0
                    Layout.preferredHeight: secretsContent.implicitHeight + 24
                    radius: Theme.radiusMedium
                    color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, 0.4)
                    border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.3)
                    border.width: 1

                    SecretsEditor {
                        id: secretsContent
                        anchors {
                            left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                            leftMargin: 16; rightMargin: 16
                        }
                        secrets: view.ready ? view.detailData.secrets : []
                    }
                }

                // Tools list
                Rectangle {
                    Layout.fillWidth: true
                    visible: view.ready && view.detailData.tools && view.detailData.tools.length > 0
                    Layout.preferredHeight: toolsCol.implicitHeight + 24
                    radius: Theme.radiusMedium
                    color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, 0.4)
                    border.color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.10)
                    border.width: 1

                    ColumnLayout {
                        id: toolsCol
                        anchors {
                            left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                            leftMargin: 16; rightMargin: 16
                        }
                        spacing: Theme.spacingSmall

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingNormal
                            Text {
                                text: "Tools"
                                color: Colors.text
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontMedium
                                font.bold: true
                            }
                            Text {
                                text: view.ready
                                    ? view.detailData.tools.filter(t => t.enabled).length + " / " + view.detailData.tools.length + " enabled"
                                    : ""
                                color: Colors.textMuted
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSmall
                            }
                        }

                        Repeater {
                            model: view.ready ? view.detailData.tools : []
                            delegate: RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: Theme.spacingNormal

                                Text {
                                    text: modelData.enabled ? "✓" : "○"
                                    color: modelData.enabled ? Colors.success : Colors.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                }
                                Text {
                                    Layout.preferredWidth: 220
                                    text: modelData.name
                                    color: Colors.text
                                    font.family: Theme.fontFamily
                                    font.pointSize: Theme.fontSmall
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.description
                                    color: Colors.textMuted
                                    font.family: Theme.fontFamily
                                    font.pointSize: Theme.fontTiny
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
