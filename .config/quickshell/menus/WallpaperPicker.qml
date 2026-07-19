import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."
import "../components"

PanelWindow {
    id: root
    property bool open: false
    property var wallpapers: []
    property string currentWallpaper: ""
    property bool applying: false
    readonly property string wallDir: Quickshell.env("WALLPAPER_DIR")
        || (Quickshell.env("HOME") + "/Pictures/wallpaper")
    readonly property var filtered: {
        const q = searchInput.text.trim().toLowerCase()
        return q ? wallpapers.filter(w => w.orig.split("/").pop().toLowerCase().includes(q)) : wallpapers
    }

    visible: open || closeAnim.running
    color: "transparent"; exclusiveZone: 0
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.namespace: "qs-wallpapers"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    onOpenChanged: {
        if (open) {
            applying = false; searchInput.text = ""; carousel.currentIndex = 0
            scanProc.running = true; currentProc.running = true
            panel.opacity = 0; panel.scale = 0.97; openAnim.start()
            Qt.callLater(() => searchInput.forceActiveFocus())
        } else closeAnim.start()
    }
    function close() { if (!applying) ControlState.wallpaperPickerOpen = false }
    function applyWallpaper(path) {
        if (!path || applying) return
        applying = true; currentWallpaper = path
        applyProc.command = [Quickshell.env("HOME") + "/.config/scripts/wallpaper_switcher.sh", "--apply", path]
        applyProc.running = true
    }
    function move(delta) {
        const count = root.filtered.length
        if (!count) return
        carousel.currentIndex = ((carousel.currentIndex + delta) % count + count) % count
    }

    Process {
        id: scanProc
        command: ["bash", Quickshell.env("HOME") + "/.config/scripts/wallpaper-thumb-gen.sh", root.wallDir]
        stdout: StdioCollector {
            onStreamFinished: {
                root.wallpapers = text.trim().split("\n").filter(x => x.length).map(line => {
                    const p = line.split("\t"); return ({ orig: p[0], thumb: p[1] || p[0] })
                })
                const i = root.wallpapers.findIndex(w => w.orig === root.currentWallpaper)
                if (i >= 0) carousel.currentIndex = i
            }
        }
    }
    Process {
        id: currentProc
        command: ["readlink", "-f", Quickshell.env("HOME") + "/.cache/current_wallpaper"]
        stdout: StdioCollector { onStreamFinished: root.currentWallpaper = text.trim() }
    }
    Process { id: applyProc; onExited: closeDelay.restart() }
    Timer { id: closeDelay; interval: 220; onTriggered: { root.applying = false; root.close() } }

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: panel; property: "opacity"; to: 1; duration: Theme.durNormal; easing.type: Easing.OutCubic }
        NumberAnimation { target: panel; property: "scale"; to: 1; duration: Theme.durNormal; easing.type: Easing.OutCubic }
    }
    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: panel; property: "opacity"; to: 0; duration: Theme.durFast }
            NumberAnimation { target: panel; property: "scale"; to: 0.97; duration: Theme.durFast }
        }
        ScriptAction { script: { ControlState.wallpaperPickerOpen = false; panel.opacity = 1; panel.scale = 1 } }
    }

    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.22); MouseArea { anchors.fill: parent; onClicked: root.close() } }
    FocusScope {
        anchors.fill: parent; focus: true
        Keys.onEscapePressed: searchInput.text.length ? searchInput.text = "" : root.close()
        Keys.onLeftPressed: root.move(-1)
        Keys.onRightPressed: root.move(1)
        Keys.onUpPressed: root.move(-1)
        Keys.onDownPressed: root.move(1)
        Keys.onReturnPressed: root.applyWallpaper(carousel.currentPath)

        Rectangle {
            id: panel
            width: Math.min(820, parent.width - 2 * Theme.spacingXL)
            height: Math.min(410, parent.height - Theme.barExclusiveZone - 2 * Theme.spacingXL)
            anchors.centerIn: parent; color: "transparent"; radius: Theme.radiusXL; clip: true
            GlassSurface { anchors.fill: parent; level: "e3"; radius: Theme.radiusXL }
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: Theme.panelPadding
                spacing: Theme.spacingNormal

                RowLayout {
                    Layout.fillWidth: true; Layout.preferredHeight: 42; spacing: Theme.spacingNormal
                    Text { text: "Wallpapers"; color: Colors.text; font.pixelSize: Theme.fontLarge; font.bold: true; font.family: Theme.fontFamily }
                    Rectangle {
                        Layout.fillWidth: true; height: 36; radius: Theme.radiusMedium
                        color: Qt.rgba(1, 1, 1, 0.055)
                        Row {
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                            spacing: Theme.spacingSmall
                            Text { text: "󰍉"; color: Colors.textMuted; font.pixelSize: Theme.fontMedium; font.family: Theme.fontIcon }
                            Item {
                                width: parent.width - 24; height: searchInput.height
                                Text { anchors.fill: parent; visible: !searchInput.text.length; text: "Search wallpapers"; color: Colors.textMuted; font.pixelSize: Theme.fontNormal; font.family: Theme.fontFamily }
                                TextInput {
                                    id: searchInput; anchors.fill: parent
                                    color: Colors.text; font.pixelSize: Theme.fontNormal; font.family: Theme.fontFamily
                                    onTextChanged: carousel.currentIndex = 0
                                    Keys.onLeftPressed: event => { root.move(-1); event.accepted = true }
                                    Keys.onRightPressed: event => { root.move(1); event.accepted = true }
                                    Keys.onUpPressed: event => { root.move(-1); event.accepted = true }
                                    Keys.onDownPressed: event => { root.move(1); event.accepted = true }
                                    Keys.onReturnPressed: event => {
                                        root.applyWallpaper(carousel.currentPath)
                                        event.accepted = true
                                    }
                                }
                            }
                        }
                    }
                    Text { text: root.filtered.length + " photos"; color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily }
                }

                Item {
                    id: carousel
                    Layout.fillWidth: true; Layout.fillHeight: true
                    property int currentIndex: 0
                    readonly property string currentPath: root.filtered.length
                        ? root.filtered[Math.min(currentIndex, root.filtered.length - 1)].orig : ""
                    function wrappedIndex(offset) {
                        const n = root.filtered.length
                        return n ? ((currentIndex + offset) % n + n) % n : -1
                    }

                    Repeater {
                        model: 5
                        delegate: Item {
                            id: card
                            required property int index
                            readonly property int offset: index - 2
                            readonly property int wallpaperIndex: carousel.wrappedIndex(offset)
                            readonly property var wallpaper: wallpaperIndex >= 0 ? root.filtered[wallpaperIndex] : null
                            readonly property bool centered: offset === 0
                            readonly property bool adjacent: Math.abs(offset) === 1
                            width: centered ? 330 : adjacent ? 210 : 135
                            height: centered ? 222 : adjacent ? 142 : 92
                            x: carousel.width / 2 + offset * 178 - width / 2
                            y: (carousel.height - height) / 2
                            z: 5 - Math.abs(offset)
                            opacity: wallpaper ? (centered ? 1 : adjacent ? 0.78 : 0.38) : 0
                            scale: centered ? 1 : 0.96
                            visible: !!wallpaper

                            Behavior on x { NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutCubic } }
                            Behavior on width { NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutCubic } }
                            Behavior on height { NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutCubic } }
                            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

                            Rectangle {
                                anchors.fill: parent; radius: Theme.radiusLarge; clip: true
                                color: Qt.rgba(1, 1, 1, 0.055)
                                Image {
                                    anchors.fill: parent; anchors.margins: 2
                                    source: card.wallpaper ? "file://" + encodeURI(card.wallpaper.thumb) : ""
                                    fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true
                                    sourceSize.width: card.centered ? 520 : 320; sourceSize.height: 340
                                }
                                Rectangle {
                                    visible: card.centered
                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                    height: 34; color: Qt.rgba(0, 0, 0, 0.68)
                                    Text {
                                        anchors { left: parent.left; right: currentMark.left; verticalCenter: parent.verticalCenter; margins: 10 }
                                        text: card.wallpaper ? card.wallpaper.orig.split("/").pop() : ""
                                        color: "white"; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily
                                        elide: Text.ElideMiddle; horizontalAlignment: Text.AlignHCenter
                                    }
                                    Text {
                                        id: currentMark
                                        visible: card.wallpaper && card.wallpaper.orig === root.currentWallpaper
                                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 10 }
                                        text: "󰄬"; color: Colors.accent; font.pixelSize: Theme.fontMedium; font.family: Theme.fontIcon
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: card.centered ? root.applyWallpaper(card.wallpaper.orig)
                                        : carousel.currentIndex = card.wallpaperIndex
                                }
                                // Border must be above the image and caption. A
                                // Rectangle.border on the container is painted
                                // below child content and was partially covered.
                                Rectangle {
                                    anchors.fill: parent; anchors.margins: 0.5
                                    radius: Theme.radiusLarge; color: "transparent"
                                    border.width: card.centered ? 2 : 1
                                    border.color: card.centered ? Colors.accent : Qt.rgba(1, 1, 1, 0.16)
                                    z: 20
                                }
                            }
                        }
                    }
                    Text { anchors.centerIn: parent; visible: !root.filtered.length; text: searchInput.text.length ? "No matching wallpapers" : "No wallpapers found"; color: Colors.textMuted; font.pixelSize: Theme.fontMedium; font.family: Theme.fontFamily }
                }

                RowLayout {
                    Layout.fillWidth: true; Layout.preferredHeight: 28
                    Text { text: root.applying ? "Applying wallpaper…" : "Click the center image or press Enter"; color: root.applying ? Colors.accent : Colors.textMuted; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily }
                    Item { Layout.fillWidth: true }
                    Text { text: "← → navigate   ·   Enter applies   ·   Esc closes"; color: Colors.textMuted; font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily }
                }
            }
        }
    }
}
