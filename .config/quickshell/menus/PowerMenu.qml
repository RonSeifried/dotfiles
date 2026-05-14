import QtQuick
import ".."
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property bool open: false

    readonly property int panelWidth: 96
    readonly property int hiddenOffset: panelWidth + 4
    readonly property int holdDurationMs: 650
    readonly property int tileHeight: 60
    readonly property int iconFontSize: 26

    readonly property var items: [
        { icon: "󰌾", label: "Lock",     cmd: "qs -p " + (Quickshell.env("HOME") || "") + "/.config/quickshell/lock ipc call lock lock" },
        { icon: "󰍃", label: "Logout",   cmd: "niri msg action quit --skip-confirmation" },
        { icon: "󰒲", label: "Suspend",  cmd: "systemctl suspend" },
        { icon: "󰜉", label: "Reboot",   cmd: "systemctl reboot" },
        { icon: "󰐥", label: "Shutdown", cmd: "systemctl poweroff" }
    ]

    property int selectedIndex: 0
    property bool holdActive: false
    property real holdProgress: 0

    visible: open || closeAnim.running
    color: "transparent"
    exclusiveZone: 0

    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.namespace: "qs-popup"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Native compositor blur (ext-background-effect-v1). x-binding follows
    // the slide-in Translate transform so blur tracks the menu in-flight —
    // qs doesn't re-poll mapToScene per frame, so explicit binds are needed.
    BackgroundEffect.blurRegion: Region {
        x: menuRect.x + slideTransform.x
        y: menuRect.y
        width: menuRect.width
        height: menuRect.height
        topLeftRadius: Theme.radiusLarge
        bottomLeftRadius: Theme.radiusLarge
    }

    onOpenChanged: {
        if (open) {
            cancelHold()
            selectedIndex = 0
            backdrop.opacity = 0
            slideTransform.x = root.hiddenOffset
            openAnim.start()
            Qt.callLater(() => scope.forceActiveFocus())
        } else {
            cancelHold()
            closeAnim.start()
        }
    }

    function close() { ControlState.powerMenuOpen = false }

    function trigger(idx) {
        const it = items[idx]
        if (!it) return
        execProc.command = ["sh", "-c", it.cmd]
        execProc.running = true
        close()
    }

    function startHold() {
        const it = items[selectedIndex]
        if (!it) return
        retractAnim.stop()
        holdAnim.stop()
        holdActive = true
        holdAnim.from = root.holdProgress
        holdAnim.to = 1
        holdAnim.duration = Math.max(80, root.holdDurationMs * (1 - root.holdProgress))
        holdAnim.start()
    }

    function cancelHold() {
        const wasActive = holdActive
        holdActive = false
        holdAnim.stop()
        if (wasActive && holdProgress > 0) {
            retractAnim.stop()
            retractAnim.from = root.holdProgress
            retractAnim.to = 0
            retractAnim.duration = Math.max(80, root.holdProgress * 220)
            retractAnim.start()
        } else {
            retractAnim.stop()
            holdProgress = 0
        }
    }

    NumberAnimation {
        id: holdAnim
        target: root
        property: "holdProgress"
        easing.type: Easing.Linear
        onFinished: {
            if (root.holdProgress >= 0.999 && root.holdActive) {
                const idx = root.selectedIndex
                root.holdActive = false
                root.trigger(idx)
            }
        }
    }
    NumberAnimation {
        id: retractAnim
        target: root
        property: "holdProgress"
        easing.type: Easing.OutQuad
    }

    // ── Open / close animations ─────────────────────────────────
    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: slideTransform; property: "x"
            to: 0
            duration: Theme.durSlide; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: backdrop; property: "opacity"
            from: 0; to: 1; duration: Theme.durNormal; easing.type: Easing.OutCubic
        }
    }

    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation {
                target: slideTransform; property: "x"
                to: root.hiddenOffset
                duration: Theme.durNormal; easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: backdrop; property: "opacity"
                to: 0; duration: Theme.durNormal; easing.type: Easing.InCubic
            }
        }
    }

    // ── Backdrop (click-outside dismiss, no dim) ────────────────
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
                if (root.holdActive) {
                    root.cancelHold()
                } else {
                    root.close()
                }
                event.accepted = true
                return
            }

            const n = root.items.length
            if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                if (root.holdActive) root.cancelHold()
                root.selectedIndex = (root.selectedIndex + 1) % n
                event.accepted = true
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                if (root.holdActive) root.cancelHold()
                root.selectedIndex = (root.selectedIndex - 1 + n) % n
                event.accepted = true
            } else if (event.key === Qt.Key_Home) {
                if (root.holdActive) root.cancelHold()
                root.selectedIndex = 0
                event.accepted = true
            } else if (event.key === Qt.Key_End) {
                if (root.holdActive) root.cancelHold()
                root.selectedIndex = n - 1
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                if (event.isAutoRepeat) { event.accepted = true; return }
                root.startHold()
                event.accepted = true
            }
        }

        Keys.onReleased: event => {
            if (event.isAutoRepeat) return
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                if (root.holdActive) root.cancelHold()
                event.accepted = true
            }
        }

        // ── Side panel ──────────────────────────────────────────
        Rectangle {
            id: menuRect
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: root.panelWidth
            height: contentColumn.implicitHeight + Theme.panelPadding * 2

            transform: Translate { id: slideTransform; x: root.hiddenOffset }
            color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, Colors.popupBgAlpha)
            border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.pillBorderAlpha)
            border.width: 1

            // Two rounded corners on left, straight on right (slide-in edge)
            topLeftRadius: Theme.radiusLarge
            bottomLeftRadius: Theme.radiusLarge
            topRightRadius: 0
            bottomRightRadius: 0
            clip: true

            // Consume clicks
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: contentColumn
                anchors {
                    left: parent.left; right: parent.right; top: parent.top
                    margins: Theme.panelPadding
                }
                spacing: Theme.spacingSmall

                Repeater {
                    model: root.items

                    delegate: Rectangle {
                        id: tile
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        height: root.tileHeight
                        radius: Theme.radiusMedium
                        clip: true

                        readonly property bool selected: root.selectedIndex === index
                        readonly property real progress: selected ? root.holdProgress : 0

                        color: selected
                            ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.pillHoverAlpha)
                            : "transparent"
                        border.color: selected
                            ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.pillBorderAlpha)
                            : "transparent"
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                        Behavior on border.color { ColorAnimation { duration: Theme.durFast } }

                        // Hold-progress fill (rises bottom → top)
                        Rectangle {
                            anchors {
                                left: parent.left; right: parent.right; bottom: parent.bottom
                            }
                            height: parent.height * tile.progress
                            color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.32)
                            radius: parent.radius
                            visible: tile.progress > 0
                        }

                        // Bottom progress bar (sharp edge indicator)
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 2
                            color: Colors.accent
                            opacity: tile.progress > 0 ? 1 : 0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: tile.modelData.icon
                            color: Colors.accent
                            font.pixelSize: root.iconFontSize
                            font.family: Theme.fontFamily
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                if (!root.holdActive) root.selectedIndex = tile.index
                            }
                            onExited: {
                                if (root.holdActive && root.selectedIndex === tile.index) root.cancelHold()
                            }
                            onPressed: {
                                root.selectedIndex = tile.index
                                root.startHold()
                            }
                            onReleased: root.cancelHold()
                            onCanceled: root.cancelHold()
                        }
                    }
                }
            }
        }
    }

    Process { id: execProc }
}
