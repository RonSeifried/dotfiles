import QtQuick
import ".."
import "../components"
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
        radius: Theme.radiusXL
    }

    onOpenChanged: {
        if (open) {
            clipSearch.text = ""
            clipSearch.forceActiveFocus()
            loadProc.running = true
            openAnim.start()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.14)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    function close() { closeAnim.start() }

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: clipRect; property: "opacity"; from: 0; to: 1; duration: Theme.durNormal }
        NumberAnimation { target: clipRect; property: "scale"; from: 0.95; to: 1; duration: Theme.durNormal }
    }

    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: clipRect; property: "opacity"; to: 0; duration: Theme.durFast }
            NumberAnimation { target: clipRect; property: "scale"; to: 0.95; duration: Theme.durFast }
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

    Process {
        id: deleteProc
        onExited: loadProc.running = true   // rescan after delete
    }

    // Floating glass panel under the bar's right end (float model: detached,
    // fully rounded, shared material).
    Rectangle {
        id: clipRect
        width: 360
        height: Math.min(searchBar.height + clipList.height
            + 2 * Theme.panelPadding + Theme.spacingNormal, 480)
        anchors {
            right: parent.right; rightMargin: Theme.barMargin
            top: parent.top; topMargin: Theme.barExclusiveZone + Theme.barMargin
        }
        radius: Theme.radiusXL
        color: "transparent"
        clip: true

        GlassSurface {
            anchors.fill: parent
            level: "e3"
            radius: Theme.radiusXL
        }

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.panelPadding }
            spacing: Theme.spacingNormal

            // Search row sits directly on the panel glass (Spotlight pattern),
            // divider below — no nested field box.
            Rectangle {
                id: searchBar
                Layout.fillWidth: true; height: 36
                color: "transparent"

                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 1
                    color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, Colors.dividerAlpha)
                }

                RowLayout {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Theme.spacingNormal }
                    spacing: Theme.spacingNormal

                    Text { text: ""; color: Colors.textMuted; font.pixelSize: Theme.fontMedium; font.family: Theme.fontIcon }
                    Item {
                        Layout.fillWidth: true
                        height: clipSearch.height

                        Text {
                            anchors.fill: parent
                            text: "Filter..."
                            color: Colors.textMuted
                            font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily
                            visible: clipSearch.text.length === 0
                            verticalAlignment: Text.AlignVCenter
                        }

                        TextInput {
                            id: clipSearch
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                            color: Colors.text; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily
                            Keys.onEscapePressed: root.close()
                            Keys.onUpPressed: clipList.decrementCurrentIndex()
                            Keys.onDownPressed: clipList.incrementCurrentIndex()
                            Keys.onReturnPressed: clipList.selectCurrent()
                            Keys.onDeletePressed: clipList.deleteCurrent()
                        }
                    }
                }
            }

            ListView {
                id: clipList
                Layout.fillWidth: true
                // Floor so the empty-state label has a stage to stand on.
                height: count === 0 ? 60 : Math.min(contentHeight, 400)
                model: {
                    const q = clipSearch.text.toLowerCase()
                    return q ? root.entries.filter(e => e.toLowerCase().includes(q)) : root.entries
                }
                spacing: 2; clip: true

                function selectCurrent() {
                    if (currentIndex >= 0 && currentIndex < model.length)
                        copyEntry(model[currentIndex])
                }

                function deleteCurrent() {
                    if (currentIndex >= 0 && currentIndex < model.length)
                        deleteEntry(model[currentIndex])
                }

                function copyEntry(entry) {
                    const id = entry.split("\t")[0]
                    copyProc.command = ["bash", "-c", `cliphist decode "${id}" | wl-copy`]
                    copyProc.running = true
                    root.close()
                }

                // Feed the exact list line back to `cliphist delete` (its
                // documented delete contract), then rescan. Entry passed as
                // argv — no shell interpolation of clipboard content.
                function deleteEntry(entry) {
                    deleteProc.command = ["bash", "-c", 'printf "%s\\n" "$1" | cliphist delete', "_", entry]
                    deleteProc.running = true
                }

                // cliphist marks non-text as "[[ binary data 24 KiB png 800x600 ]]"
                // — render that as a tidy image label instead of raw markup.
                function prettyLabel(entry) {
                    const p = entry.split("\t")
                    const body = p.length > 1 ? p.slice(1).join("\t") : entry
                    const m = body.match(/^\[\[ binary data ([0-9.]+ \S+) (\w+) (\d+x\d+) \]\]$/)
                    if (m) return `󰋩  Image · ${m[2]} · ${m[3]} · ${m[1]}`
                    return body
                }

                delegate: Rectangle {
                    id: clipDelegate
                    required property string modelData
                    required property int index
                    width: ListView.view.width; height: 32; radius: Theme.radiusSmall
                    // List row: transparent idle, white on hover, accent when selected.
                    color: {
                        if (clipList.currentIndex === clipDelegate.index) return Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.22)
                        if (hoverArea.containsMouse) return Qt.rgba(1, 1, 1, Theme.hoverBrightness)
                        return "transparent"
                    }

                    Text {
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 10 }
                        anchors.rightMargin: delBtn.visible ? 30 : 10
                        text: clipList.prettyLabel(clipDelegate.modelData)
                        color: Colors.text; font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily
                        elide: Text.ElideRight; maximumLineCount: 1
                    }

                    MouseArea {
                        id: hoverArea; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clipList.copyEntry(clipDelegate.modelData)
                        onEntered: clipList.currentIndex = clipDelegate.index
                    }

                    // Hover delete — also on the Delete key via the search field.
                    Text {
                        id: delBtn
                        visible: hoverArea.containsMouse || delHover.containsMouse
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
                        text: "󰅖"
                        color: delHover.containsMouse ? Colors.error : Colors.textMuted
                        font.pixelSize: Theme.fontSmall; font.family: Theme.fontIcon
                        MouseArea {
                            id: delHover; anchors.fill: parent; anchors.margins: -5
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: clipList.deleteEntry(clipDelegate.modelData)
                        }
                    }
                }

                // Empty state — a bare glass void reads as "broken".
                Text {
                    anchors.centerIn: parent
                    visible: clipList.count === 0
                    text: clipSearch.text.length > 0 ? "No matches" : "Clipboard is empty"
                    color: Colors.textMuted
                    font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily
                }
            }
        }
    }
}
