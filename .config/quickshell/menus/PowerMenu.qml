import QtQuick
import ".."
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property bool open: false
    property string confirmAction: ""
    property string confirmLabel: ""
    property bool confirming: confirmAction !== ""

    readonly property int panelWidth: 240
    readonly property int hiddenOffset: panelWidth + 4
    readonly property var items: [
        { icon: "󰌾", label: "Lock",     cmd: "qs -p " + (Quickshell.env("HOME") || "") + "/.config/quickshell/lock ipc call lock lock", confirm: false },
        { icon: "󰍃", label: "Logout",   cmd: "niri msg action quit --skip-confirmation", confirm: true  },
        { icon: "󰒲", label: "Suspend",  cmd: "systemctl suspend",  confirm: false },
        { icon: "󰜉", label: "Reboot",   cmd: "systemctl reboot",   confirm: true  },
        { icon: "󰐥", label: "Shutdown", cmd: "systemctl poweroff", confirm: true  }
    ]

    property int selectedIndex: 0
    property int confirmSelectedIndex: 1  // 0 = Yes, 1 = Cancel (default safe)

    visible: open || closeAnim.running
    color: "transparent"
    exclusiveZone: 0

    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.namespace: "qs-popup"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    onOpenChanged: {
        if (open) {
            confirmAction = ""
            confirmLabel = ""
            selectedIndex = 0
            confirmSelectedIndex = 1
            backdrop.opacity = 0
            slideTransform.x = root.hiddenOffset
            openAnim.start()
            Qt.callLater(() => scope.forceActiveFocus())
        } else {
            closeAnim.start()
        }
    }

    function close() { ControlState.powerMenuOpen = false }

    function triggerItem(idx) {
        const it = items[idx]
        if (!it) return
        if (it.confirm) {
            confirmLabel = it.label
            confirmAction = it.cmd
            confirmSelectedIndex = 1
        } else {
            execProc.command = ["sh", "-c", it.cmd]
            execProc.running = true
            close()
        }
    }

    function triggerConfirm() {
        if (confirmSelectedIndex === 0) {
            execProc.command = ["sh", "-c", confirmAction]
            execProc.running = true
            close()
        } else {
            confirmAction = ""
            confirmLabel = ""
        }
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

    // ── Backdrop (click-outside dismiss) ────────────────────────
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)
        opacity: 0
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (root.confirming) {
                    root.confirmAction = ""
                    root.confirmLabel = ""
                } else {
                    root.close()
                }
                event.accepted = true
                return
            }

            if (root.confirming) {
                if (event.key === Qt.Key_Left || event.key === Qt.Key_Right ||
                    event.key === Qt.Key_Tab || event.key === Qt.Key_H || event.key === Qt.Key_L) {
                    root.confirmSelectedIndex = (root.confirmSelectedIndex + 1) % 2
                    event.accepted = true
                } else if (event.key === Qt.Key_Y) {
                    root.confirmSelectedIndex = 0
                    root.triggerConfirm()
                    event.accepted = true
                } else if (event.key === Qt.Key_N) {
                    root.confirmAction = ""
                    root.confirmLabel = ""
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    root.triggerConfirm()
                    event.accepted = true
                }
                return
            }

            const n = root.items.length
            if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                root.selectedIndex = (root.selectedIndex + 1) % n
                event.accepted = true
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                root.selectedIndex = (root.selectedIndex - 1 + n) % n
                event.accepted = true
            } else if (event.key === Qt.Key_Home) {
                root.selectedIndex = 0
                event.accepted = true
            } else if (event.key === Qt.Key_End) {
                root.selectedIndex = n - 1
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                root.triggerItem(root.selectedIndex)
                event.accepted = true
            } else if (event.key === Qt.Key_L) {
                root.selectedIndex = 0; root.triggerItem(0); event.accepted = true
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

            Item {
                id: contentColumn
                anchors {
                    left: parent.left; right: parent.right; top: parent.top
                    margins: Theme.panelPadding
                }
                implicitHeight: root.confirming ? confirmPanel.implicitHeight : mainPanel.implicitHeight

                ColumnLayout {
                    id: mainPanel
                    visible: !root.confirming
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    spacing: Theme.spacingTight

                    Text {
                        text: "Power"
                        color: Colors.textMuted
                        font.pixelSize: Theme.fontSmall; font.bold: true
                        font.family: Theme.fontFamily
                        Layout.leftMargin: Theme.spacingSmall; Layout.topMargin: Theme.spacingTight
                        Layout.bottomMargin: Theme.spacingTight
                    }

                    Repeater {
                        model: root.items

                        delegate: Rectangle {
                            id: powerDelegate
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            height: 40
                            radius: Theme.radiusSmall

                            readonly property bool selected: root.selectedIndex === index

                            color: selected
                                ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.pillHoverAlpha)
                                : "transparent"
                            border.color: selected
                                ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.pillBorderAlpha)
                                : "transparent"
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.durFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.durFast } }

                            RowLayout {
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: Theme.spacingLarge; rightMargin: Theme.spacingLarge
                                }
                                spacing: Theme.spacingLarge

                                Text {
                                    text: powerDelegate.modelData.icon
                                    color: Colors.accent
                                    font.pixelSize: Theme.fontLarge + 2
                                    font.family: Theme.fontFamily
                                }
                                Text {
                                    text: powerDelegate.modelData.label
                                    color: Colors.text
                                    font.pixelSize: Theme.fontMedium
                                    font.family: Theme.fontFamily
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.selectedIndex = powerDelegate.index
                                onClicked: root.triggerItem(powerDelegate.index)
                            }
                        }
                    }
                }

                ColumnLayout {
                    id: confirmPanel
                    visible: root.confirming
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    spacing: Theme.spacingLarge

                    Text {
                        text: root.confirmLabel + "?"
                        color: Colors.text
                        font.pixelSize: Theme.fontLarge; font.bold: true
                        font.family: Theme.fontFamily
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Theme.spacingTight
                    }

                    Text {
                        text: "Are you sure?"
                        color: Colors.textMuted
                        font.pixelSize: Theme.fontNormal
                        font.family: Theme.fontFamily
                        Layout.alignment: Qt.AlignHCenter
                    }

                    RowLayout {
                        Layout.fillWidth: true; spacing: Theme.spacingNormal
                        Layout.topMargin: Theme.spacingSmall

                        Rectangle {
                            id: yesBtn
                            Layout.fillWidth: true; height: 36
                            radius: Theme.radiusSmall

                            readonly property bool selected: root.confirmSelectedIndex === 0

                            color: selected
                                ? Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.35)
                                : Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.18)
                            border.color: selected
                                ? Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.85)
                                : Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.4)
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.durFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.durFast } }

                            Text {
                                anchors.centerIn: parent; text: "Yes"
                                color: Colors.text
                                font.pixelSize: Theme.fontMedium
                                font.bold: yesBtn.selected
                                font.family: Theme.fontFamily
                            }
                            MouseArea {
                                anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.confirmSelectedIndex = 0
                                onClicked: { root.confirmSelectedIndex = 0; root.triggerConfirm() }
                            }
                        }

                        Rectangle {
                            id: cancelBtn
                            Layout.fillWidth: true; height: 36
                            radius: Theme.radiusSmall

                            readonly property bool selected: root.confirmSelectedIndex === 1

                            color: selected
                                ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.pillHoverAlpha)
                                : Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.4)
                            border.color: selected
                                ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.7)
                                : Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.25)
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.durFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.durFast } }

                            Text {
                                anchors.centerIn: parent; text: "Cancel"
                                color: cancelBtn.selected ? Colors.text : Colors.textMuted
                                font.pixelSize: Theme.fontMedium
                                font.bold: cancelBtn.selected
                                font.family: Theme.fontFamily
                            }
                            MouseArea {
                                anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.confirmSelectedIndex = 1
                                onClicked: { root.confirmSelectedIndex = 1; root.triggerConfirm() }
                            }
                        }
                    }

                    // Hint row
                    Text {
                        text: "↵ confirm   ←/→ switch   esc back"
                        color: Colors.textMuted
                        font.pixelSize: Theme.fontTiny
                        font.family: Theme.fontFamily
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Theme.spacingTight
                    }
                }
            }
        }
    }

    Process { id: execProc }
}
