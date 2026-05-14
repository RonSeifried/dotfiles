import QtQuick
import ".."
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property bool open: false
    property var wallpapers: []
    property string currentWallpaper: ""
    property bool applying: false
    readonly property string wallDir: (Quickshell.env("WALLPAPER_DIR") || (Quickshell.env("HOME") + "/Pictures/wallpaper"))

    // ── Layout constants ────────────────────────────────────────
    readonly property int panelHeight: 360
    readonly property int hiddenOffset: panelHeight + 8
    readonly property int centerW: 320
    readonly property int centerH: 215
    readonly property int adjW: 200
    readonly property int adjH: 130
    readonly property int farW: 130
    readonly property int farH: 85
    readonly property int stepX: 175
    readonly property int preloadRadius: 3   // preload only neighbors

    visible: open || closeAnim.running
    color: "transparent"
    exclusiveZone: 0
    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.namespace: "qs-popup"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    onOpenChanged: {
        if (open) {
            applying = false
            scanProc.running = true
            currentProc.running = true
            searchInput.text = ""
            carousel.currentIndex = 0
            backdrop.opacity = 0
            slideTransform.y = root.hiddenOffset
            openAnim.start()
            Qt.callLater(() => searchInput.forceActiveFocus())
        } else {
            closeAnim.start()
        }
    }

    function close() {
        if (applying) return
        ControlState.wallpaperPickerOpen = false
    }

    function applyWallpaper(path) {
        if (!path || applying) return
        root.currentWallpaper = path
        applying = true
        pulseAnim.restart()
        applyProc.command = [Quickshell.env("HOME") + "/.config/scripts/wallpaper_switcher.sh", "--apply", path]
        applyProc.running = true
    }

    Process {
        id: scanProc
        command: ["bash", Quickshell.env("HOME") + "/.config/scripts/wallpaper-thumb-gen.sh", root.wallDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(l => l.length > 0)
                root.wallpapers = lines.map(l => {
                    const parts = l.split("\t")
                    return { orig: parts[0], thumb: parts[1] || parts[0] }
                })
                if (root.currentWallpaper) {
                    const idx = root.wallpapers.findIndex(w => w.orig === root.currentWallpaper)
                    if (idx >= 0) carousel.currentIndex = idx
                }
            }
        }
    }

    Process {
        id: currentProc
        command: ["readlink", "-f", Quickshell.env("HOME") + "/.cache/current_wallpaper"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.currentWallpaper = text.trim()
                if (root.currentWallpaper) {
                    const idx = root.wallpapers.findIndex(w => w.orig === root.currentWallpaper)
                    if (idx >= 0) carousel.currentIndex = idx
                }
            }
        }
    }

    Process {
        id: applyProc
        onExited: (code, status) => {
            // Brief settle, then close (palette already starts morphing via Colors.qml watcher)
            closeDelay.restart()
        }
    }

    Timer { id: closeDelay; interval: 280; onTriggered: { root.applying = false; root.close() } }

    // ── Open / close animations ─────────────────────────────────
    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: slideTransform; property: "y"
            to: 0
            duration: Theme.durSlide; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: backdrop; property: "opacity"
            from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic
        }
    }
    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation {
                target: slideTransform; property: "y"
                to: root.hiddenOffset
                duration: Theme.durNormal; easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: backdrop; property: "opacity"
                to: 0; duration: 220; easing.type: Easing.InCubic
            }
        }
    }

    // ── Pulse on apply (center card briefly scales up) ──────────
    SequentialAnimation {
        id: pulseAnim
        NumberAnimation { target: centerScaler; property: "scale"; to: 1.06; duration: 160; easing.type: Easing.OutQuad }
        NumberAnimation { target: centerScaler; property: "scale"; to: 1.0;  duration: 220; easing.type: Easing.OutCubic }
    }

    // Holder used by pulseAnim — center card binds its scale to this
    QtObject { id: centerScaler; property real scale: 1.0 }

    // ── Off-screen preloader: only current ± preloadRadius ──────
    Item {
        x: -10000; y: -10000
        width: 1; height: 1
        Repeater {
            model: {
                const n = root.wallpapers.length
                if (n === 0) return []
                const r = root.preloadRadius
                const out = []
                for (let i = -r; i <= r; ++i) {
                    const idx = ((carousel.currentIndex + i) % n + n) % n
                    const w = root.wallpapers[idx]
                    if (w && w.thumb && out.indexOf(w.thumb) === -1) out.push(w.thumb)
                }
                return out
            }
            delegate: Image {
                required property string modelData
                source: modelData ? "file://" + modelData : ""
                sourceSize.width: 480
                sourceSize.height: 320
                cache: true
                asynchronous: true
                width: 1; height: 1
                fillMode: Image.PreserveAspectCrop
            }
        }
    }

    // ── Backdrop (click-outside close, no dim) ──────────────────
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "transparent"
        opacity: 0
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (searchInput.activeFocus && searchInput.text.length > 0) {
                    searchInput.text = ""
                } else {
                    root.close()
                }
                event.accepted = true
                return
            }
            if (carousel.filtered.length === 0) return
            if (event.key === Qt.Key_Left) {
                carousel.prev(); event.accepted = true
            } else if (event.key === Qt.Key_Right) {
                carousel.next(); event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.applyWallpaper(carousel.currentPath); event.accepted = true
            }
        }

        // ── Main panel ──────────────────────────────────────────
        Rectangle {
            id: panel
            width: Math.max(760, Math.min(parent.width * 0.55, 1100))
            height: root.panelHeight
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, Colors.popupBgAlpha)
            clip: true

            // Top corners rounded, bottom flush with screen edge
            topLeftRadius: Theme.radiusLarge
            topRightRadius: Theme.radiusLarge
            bottomLeftRadius: 0
            bottomRightRadius: 0

            // Soft accent border (matches bar pill style)
            border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.pillBorderAlpha)
            border.width: 1

            transform: Translate { id: slideTransform; y: root.hiddenOffset }

            // Consume clicks on panel
            MouseArea { anchors.fill: parent }

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                // ── Header: title-pill + search-pill + count-pill ─
                Row {
                    width: parent.width
                    spacing: Theme.spacingNormal
                    height: Theme.pillHeight + 4

                    // Title pill
                    Rectangle {
                        height: Theme.pillHeight
                        anchors.verticalCenter: parent.verticalCenter
                        radius: Theme.radiusPill
                        color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, Colors.pillBgAlpha)
                        border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.pillBorderAlpha)
                        border.width: 1
                        width: titleRow.implicitWidth + 22

                        Row {
                            id: titleRow
                            anchors.centerIn: parent
                            spacing: 7
                            Text {
                                text: "󰸉"
                                color: Colors.accent
                                font.pixelSize: Theme.fontLarge
                                font.family: Theme.fontFamily
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Wallpapers"
                                color: Colors.text
                                font.pixelSize: Theme.fontMedium
                                font.bold: true
                                font.family: Theme.fontFamily
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Search pill (grows to fill)
                    Rectangle {
                        id: searchPill
                        height: Theme.pillHeight
                        width: panel.width - 28 - titleRow.implicitWidth - 22 - countPill.width - applyBadge.width - Theme.spacingNormal * (applyBadge.visible ? 4 : 3)
                        anchors.verticalCenter: parent.verticalCenter
                        radius: Theme.radiusPill
                        color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, Colors.pillBgAlpha * 0.65)
                        border.color: searchInput.activeFocus
                            ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.75)
                            : Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.pillBorderAlpha * 0.7)
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: Theme.durHover } }

                        Row {
                            anchors {
                                left: parent.left; right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 12; rightMargin: 12
                            }
                            spacing: 7

                            Text {
                                text: ""
                                color: searchInput.activeFocus ? Colors.accent : Colors.textMuted
                                font.pixelSize: Theme.fontMedium
                                font.family: Theme.fontFamily
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: Theme.durHover } }
                            }
                            Item {
                                width: parent.width - 24
                                height: Theme.pillHeight
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.fill: parent
                                    text: "Type to filter…"
                                    color: Colors.textMuted
                                    font.pixelSize: Theme.fontNormal
                                    font.family: Theme.fontFamily
                                    visible: searchInput.text.length === 0
                                    verticalAlignment: Text.AlignVCenter
                                    opacity: searchInput.activeFocus ? 0.55 : 0.85
                                    Behavior on opacity { NumberAnimation { duration: Theme.durHover } }
                                }
                                TextInput {
                                    id: searchInput
                                    anchors {
                                        left: parent.left; right: parent.right
                                        verticalCenter: parent.verticalCenter
                                    }
                                    color: Colors.text
                                    font.pixelSize: Theme.fontNormal
                                    font.family: Theme.fontFamily
                                    selectByMouse: true
                                    onTextChanged: carousel.currentIndex = 0
                                    Keys.onPressed: event => {
                                        if (event.key === Qt.Key_Left) {
                                            carousel.prev(); event.accepted = true
                                        } else if (event.key === Qt.Key_Right) {
                                            carousel.next(); event.accepted = true
                                        }
                                    }
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            onClicked: searchInput.forceActiveFocus()
                        }
                    }

                    // Count pill
                    Rectangle {
                        id: countPill
                        height: Theme.pillHeight
                        width: countText.implicitWidth + 18
                        anchors.verticalCenter: parent.verticalCenter
                        radius: Theme.radiusPill
                        color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, Colors.pillBgAlpha * 0.65)
                        border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.pillBorderAlpha * 0.7)
                        border.width: 1
                        Text {
                            id: countText
                            anchors.centerIn: parent
                            text: carousel.filtered.length + " / " + root.wallpapers.length
                            color: Colors.textMuted
                            font.pixelSize: Theme.fontSmall
                            font.family: Theme.fontFamily
                        }
                    }

                    // Apply-state badge (visible only while applying)
                    Rectangle {
                        id: applyBadge
                        visible: root.applying
                        height: Theme.pillHeight
                        width: visible ? applyBadgeRow.implicitWidth + 22 : 0
                        anchors.verticalCenter: parent.verticalCenter
                        radius: Theme.radiusPill
                        color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.22)
                        border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.7)
                        border.width: 1
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 180 } }

                        Row {
                            id: applyBadgeRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "󰜗"
                                color: Colors.accent
                                font.pixelSize: Theme.fontMedium
                                font.family: Theme.fontFamily
                                anchors.verticalCenter: parent.verticalCenter
                                RotationAnimator on rotation {
                                    from: 0; to: 360
                                    duration: 1200
                                    loops: Animation.Infinite
                                    running: root.applying
                                }
                            }
                            Text {
                                text: "Applying"
                                color: Colors.text
                                font.pixelSize: Theme.fontSmall
                                font.bold: true
                                font.family: Theme.fontFamily
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                // ── Carousel ──────────────────────────────────
                Item {
                    id: carousel
                    width: parent.width
                    height: 235

                    property int currentIndex: 0
                    property var filtered: {
                        const s = searchInput.text.trim().toLowerCase()
                        if (!s) return root.wallpapers
                        return root.wallpapers.filter(w => w.orig.split("/").pop().toLowerCase().includes(s))
                    }
                    readonly property string currentPath: filtered.length > 0
                        ? filtered[Math.max(0, Math.min(currentIndex, filtered.length - 1))].orig
                        : ""

                    function indexAt(offset) {
                        const len = filtered.length
                        if (len === 0) return -1
                        return ((currentIndex + offset) % len + len) % len
                    }
                    function next() {
                        if (filtered.length === 0) return
                        currentIndex = (currentIndex + 1) % filtered.length
                    }
                    function prev() {
                        if (filtered.length === 0) return
                        currentIndex = (currentIndex - 1 + filtered.length) % filtered.length
                    }

                    onFilteredChanged: {
                        if (currentIndex >= filtered.length) currentIndex = 0
                    }

                    Repeater {
                        model: 5
                        delegate: Item {
                            id: cell
                            required property int index
                            readonly property int offset: index - 2
                            readonly property int wpIdx: carousel.indexAt(offset)
                            readonly property var wpItem: wpIdx >= 0 ? carousel.filtered[wpIdx] : null
                            readonly property string wpPath: wpItem ? wpItem.orig : ""
                            readonly property string wpThumb: wpItem ? wpItem.thumb : ""
                            readonly property bool isCenter: offset === 0
                            readonly property bool isAdjacent: Math.abs(offset) === 1

                            width: isCenter ? root.centerW : isAdjacent ? root.adjW : root.farW
                            height: isCenter ? root.centerH : isAdjacent ? root.adjH : root.farH
                            x: carousel.width / 2 + offset * root.stepX - width / 2
                            y: (carousel.height - height) / 2
                            z: 10 - Math.abs(offset)
                            opacity: carousel.filtered.length === 0 ? 0
                                : Math.abs(offset) === 2 ? 0.4
                                : isAdjacent ? 0.82
                                : 1
                            visible: wpPath !== ""
                            scale: isCenter ? centerScaler.scale : 1.0
                            transformOrigin: Item.Center

                            Behavior on x       { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 0.7 } }
                            Behavior on width   { NumberAnimation { duration: 380; easing.type: Easing.OutQuart } }
                            Behavior on height  { NumberAnimation { duration: 380; easing.type: Easing.OutQuart } }
                            Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                            // Glow halo (only for center card)
                            Rectangle {
                                visible: cell.isCenter && cell.wpPath !== ""
                                anchors.centerIn: parent
                                width: parent.width + 22
                                height: parent.height + 22
                                radius: Theme.radiusLarge + 4
                                color: "transparent"
                                border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.18)
                                border.width: 6
                                opacity: 0.85
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radiusMedium
                                color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.35)
                                border.color: cell.isCenter
                                    ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.95)
                                    : Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.pillBorderAlpha * 0.4)
                                border.width: cell.isCenter ? 2 : 1
                                clip: true

                                Behavior on border.color { ColorAnimation { duration: 240 } }

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    source: cell.wpThumb ? "file://" + cell.wpThumb : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    sourceSize.width: 480
                                    sourceSize.height: 320
                                    smooth: true
                                    mipmap: true
                                }

                                // Filename label on center card
                                Rectangle {
                                    visible: cell.isCenter && cell.wpPath !== ""
                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                    height: nameLabel.implicitHeight + 10
                                    color: Qt.rgba(Colors.bg.r, Colors.bg.g, Colors.bg.b, 0.78)
                                    Text {
                                        id: nameLabel
                                        anchors {
                                            left: parent.left; right: parent.right
                                            verticalCenter: parent.verticalCenter
                                            leftMargin: 10; rightMargin: 10
                                        }
                                        text: cell.wpPath ? cell.wpPath.split("/").pop() : ""
                                        color: Colors.text
                                        font.pixelSize: Theme.fontSmall
                                        font.family: Theme.fontFamily
                                        elide: Text.ElideMiddle
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }

                                // "current" badge
                                Rectangle {
                                    visible: cell.wpPath === root.currentWallpaper && cell.wpPath !== ""
                                    anchors { top: parent.top; right: parent.right; margins: 6 }
                                    height: 16
                                    width: currentBadgeText.implicitWidth + 12
                                    radius: Theme.radiusPill
                                    color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.92)
                                    Text {
                                        id: currentBadgeText
                                        anchors.centerIn: parent
                                        text: "current"
                                        color: Colors.bg
                                        font.pixelSize: Theme.fontTiny
                                        font.bold: true
                                        font.family: Theme.fontFamily
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (cell.isCenter) {
                                            root.applyWallpaper(cell.wpPath)
                                        } else if (cell.wpIdx >= 0) {
                                            carousel.currentIndex = cell.wpIdx
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: carousel.filtered.length === 0
                        text: searchInput.text ? "No matches" : "No wallpapers found"
                        color: Colors.textMuted
                        font.pixelSize: Theme.fontMedium
                        font.family: Theme.fontFamily
                    }
                }

                // ── Footer hint pill ──────────────────────────
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: Theme.pillHeight - 4
                    width: hintsRow.implicitWidth + 24
                    radius: Theme.radiusPill
                    color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, Colors.pillBgAlpha * 0.6)
                    border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.pillBorderAlpha * 0.6)
                    border.width: 1

                    Row {
                        id: hintsRow
                        anchors.centerIn: parent
                        spacing: 10
                        readonly property color sep: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.4)

                        Text { text: "←/→ navigate"; color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle { width: 1; height: 12; color: hintsRow.sep; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "↵ apply";       color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle { width: 1; height: 12; color: hintsRow.sep; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "type to search"; color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle { width: 1; height: 12; color: hintsRow.sep; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "esc close";     color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }
}
