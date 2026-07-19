import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import "../../.."
import ".."

Item {
    id: view

    property string filter: ""
    property string inspectName: ""
    property string inspectText: ""
    property bool inspectVisible: false

    Process {
        id: inspectProc
        property string targetName: ""
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    view.inspectText = (j && j.raw) ? j.raw : text
                } catch (e) {
                    view.inspectText = text
                }
            }
        }
    }

    function runInspect(name) {
        inspectName = name
        inspectText = "Loading…"
        inspectVisible = true
        if (inspectProc.running) inspectProc.running = false
        inspectProc.targetName = name
        inspectProc.command = [McpState.helper, "tool-inspect", name]
        inspectProc.running = true
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingLarge

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingLarge
            Text {
                text: "Tools"
                color: Colors.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLarge
                font.bold: true
            }
            Text {
                text: McpState.tools.length + " available"
                color: Colors.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
            }
            Item { Layout.fillWidth: true }
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
                        font.family: Theme.fontIcon
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
                        font.pixelSize: Theme.fontSmall
                        onTextChanged: view.filter = text
                    }
                }
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !view.inspectVisible
            clip: true
            spacing: 2
            model: McpState.tools.filter(t =>
                view.filter === "" || t.name.toLowerCase().includes(view.filter.toLowerCase()))
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width
                height: 36
                radius: Theme.radiusSmall
                color: toolHover.containsMouse
                    ? Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.06)
                    : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: Theme.spacingNormal

                    Text {
                        text: "󰒓"
                        color: Colors.accent
                        font.family: Theme.fontIcon
                        font.pixelSize: 13
                    }
                    Text {
                        Layout.preferredWidth: 280
                        text: modelData.name
                        color: Colors.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.description
                        color: Colors.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTiny
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: toolHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.runInspect(modelData.name)
                }
            }
        }

        // Inspect pane
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: view.inspectVisible
            radius: Theme.radiusMedium
            color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, 0.5)
            border.color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.10)
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: Theme.spacingNormal

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: view.inspectName
                        color: Colors.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontMedium
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        Layout.preferredHeight: 24
                        Layout.preferredWidth: 24
                        radius: Theme.radiusSmall
                        color: closeHover.containsMouse
                            ? Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.10)
                            : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: Colors.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                        MouseArea {
                            id: closeHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.inspectVisible = false
                        }
                    }
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    TextEdit {
                        readOnly: true
                        selectByMouse: true
                        wrapMode: TextEdit.Wrap
                        color: Colors.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTiny
                        text: view.inspectText
                    }
                }
            }
        }
    }
}
