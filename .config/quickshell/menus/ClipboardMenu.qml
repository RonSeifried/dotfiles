import QtQuick
import ".."
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property bool open: false
    property var entries: []

    visible: open
    color: "transparent"
    exclusiveZone: 0

    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.namespace: "qs-popup"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Native compositor blur (ext-background-effect-v1).
    BackgroundEffect.blurRegion: Region {
        item: clipRect
        radius: 14
    }

    onOpenChanged: {
        if (open) {
            clipSearch.text = ""
            clipSearch.forceActiveFocus()
            loadProc.running = true
            openAnim.start()
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    function close() { closeAnim.start() }

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: clipRect; property: "opacity"; from: 0; to: 1; duration: 180 }
        NumberAnimation { target: clipRect; property: "scale"; from: 0.95; to: 1; duration: 180 }
    }

    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: clipRect; property: "opacity"; to: 0; duration: 140 }
            NumberAnimation { target: clipRect; property: "scale"; to: 0.95; duration: 140 }
        }
        ScriptAction { script: { ControlState.clipboardOpen = false; clipRect.opacity = 1; clipRect.scale = 1 } }
    }

    Process {
        id: loadProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = text.trim().split("\n")
                    .filter(l => l.length > 0)
                    .slice(0, 50)
            }
        }
    }

    Process {
        id: copyProc
    }

    Rectangle {
        id: clipRect
        width: 360
        height: Math.min(searchBar.height + clipList.height + 28, 480)
        anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: 48 }
        radius: 14
        color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, 0.95)
        border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.3)
        border.width: 1
        clip: true

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
            spacing: 6

            Rectangle {
                id: searchBar
                Layout.fillWidth: true; height: 36; radius: 8
                color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.6)
                border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.3); border.width: 1

                RowLayout {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 10 }
                    spacing: 8

                    Text { text: ""; color: Colors.textMuted; font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font" }
                    Item {
                        Layout.fillWidth: true
                        height: clipSearch.height

                        Text {
                            anchors.fill: parent
                            text: "Filter..."
                            color: Colors.textMuted
                            font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"
                            visible: clipSearch.text.length === 0
                            verticalAlignment: Text.AlignVCenter
                        }

                        TextInput {
                            id: clipSearch
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                            color: Colors.text; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"
                            Keys.onEscapePressed: root.close()
                            Keys.onUpPressed: clipList.decrementCurrentIndex()
                            Keys.onDownPressed: clipList.incrementCurrentIndex()
                            Keys.onReturnPressed: clipList.selectCurrent()
                        }
                    }
                }
            }

            ListView {
                id: clipList
                Layout.fillWidth: true
                height: Math.min(contentHeight, 400)
                model: {
                    const q = clipSearch.text.toLowerCase()
                    return q ? root.entries.filter(e => e.toLowerCase().includes(q)) : root.entries
                }
                spacing: 2; clip: true

                function selectCurrent() {
                    if (currentIndex >= 0 && currentIndex < model.length)
                        copyEntry(model[currentIndex])
                }

                function copyEntry(entry) {
                    const id = entry.split("\t")[0]
                    copyProc.command = ["bash", "-c", `cliphist decode "${id}" | wl-copy`]
                    copyProc.running = true
                    root.close()
                }

                delegate: Rectangle {
                    id: clipDelegate
                    required property string modelData
                    required property int index
                    width: ListView.view.width; height: 32; radius: 6
                    color: {
                        if (clipList.currentIndex === clipDelegate.index) return Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.22)
                        if (hoverArea.containsMouse) return Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.1)
                        return "transparent"
                    }

                    Text {
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 10 }
                        text: { const p = clipDelegate.modelData.split("\t"); return p.length > 1 ? p.slice(1).join("\t") : clipDelegate.modelData }
                        color: Colors.text; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"
                        elide: Text.ElideRight; maximumLineCount: 1
                    }

                    MouseArea {
                        id: hoverArea; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clipList.copyEntry(clipDelegate.modelData)
                        onEntered: clipList.currentIndex = clipDelegate.index
                    }
                }
            }
        }
    }
}
