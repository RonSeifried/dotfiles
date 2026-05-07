import QtQuick
import QtQuick.Layouts
import ".."
import "popups"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import Quickshell.Services.SystemTray

PanelWindow {
    id: root

    color: "transparent"
    implicitHeight: Theme.barHeight
    margins { left: Theme.barMargin; right: Theme.barMargin; top: Theme.barTopMargin }
    WlrLayershell.namespace: "qs-bar"
    WlrLayershell.keyboardFocus: panelOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    anchors { top: true; left: true; right: true }
    exclusiveZone: Theme.barExclusiveZone

    // Corners flat while EITHER popup is visible
    property bool panelOpen: rightPanelPopup.popupVisible || toastPopup.toastVisible
    property bool pinnedOpen: false

    // Close on ToplevelManager focus change (click elsewhere)
    Connections {
        target: ToplevelManager
        function onActiveToplevelChanged() {
            if (!root.pinnedOpen) ControlState.rightPanel = "none"
        }
    }

    // Idle inhibitor — systemd-inhibit child process lives while inhibited
    Process {
        id: idleInhibitProc
        command: ["systemd-inhibit", "--what=idle", "--who=quickshell", "--why=user-toggled", "sleep", "infinity"]
        running: ControlState.idleInhibited
    }

    // ── Popups ───────────────────────────────────────────────────
    RightPanelPopup {
        id: rightPanelPopup
        bar: root
        anchorItem: rightPill
        pinnedOpen: root.pinnedOpen
        pillHovered: rightPillHover.hovered
        onPinnedClosed: root.pinnedOpen = false
    }

    ToastPopup {
        id: toastPopup
        bar: root
        anchorItem: rightPill
    }

    // ── Bar content ──────────────────────────────────────────────
    Item {
        id: barContent
        anchors.fill: parent
        opacity: 0; y: -10

        Component.onCompleted: startupAnim.start()
        SequentialAnimation {
            id: startupAnim
            PauseAnimation { duration: 80 }
            ParallelAnimation {
                NumberAnimation { target: barContent; property: "opacity"; from: 0; to: 1; duration: 350; easing.type: Easing.OutCubic }
                NumberAnimation { target: barContent; property: "y"; from: -10; to: 0; duration: 350; easing.type: Easing.OutCubic }
            }
        }

        RowLayout {
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom }
            spacing: Theme.spacingSmall

            // ── Left pill: workspaces ────────────────────────────
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: Theme.pillHeight
                implicitWidth: workspacesRow.implicitWidth + 18
                radius: Theme.radiusPill
                color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, Colors.pillBgAlpha)
                border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.pillBorderAlpha)
                border.width: 1
                Behavior on implicitWidth { NumberAnimation { duration: Theme.durHover; easing.type: Easing.OutQuad } }
                Workspaces { id: workspacesRow; anchors.centerIn: parent; output: root.screen ? root.screen.name : "" }
            }

            // ── Center pill: window title ────────────────────────
            Rectangle {
                Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                implicitHeight: Theme.pillHeight; radius: Theme.radiusPill
                color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, Colors.pillBgAlpha * 0.6)
                border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.pillBorderAlpha * 0.7)
                border.width: 1

                WindowTitle {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 12 }
                }
            }

            // ── MPRIS pill: shows when playing, animates in/out ──
            Rectangle {
                id: mprisPill
                Layout.alignment: Qt.AlignVCenter
                readonly property bool show: MprisState.isPlaying
                readonly property real targetWidth: mediaContent.implicitWidth + 24
                implicitHeight: Theme.pillHeight
                implicitWidth: show ? targetWidth : 0
                radius: Theme.radiusPill
                color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, Colors.pillBgAlpha)
                border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.pillBorderAlpha)
                border.width: 1
                opacity: show ? 1 : 0
                clip: true
                visible: implicitWidth > 1
                Behavior on implicitWidth { NumberAnimation { duration: Theme.durSlide; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutCubic } }

                MediaPlayer {
                    id: mediaContent
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 12 }
                }
            }

            // ── Right pill: status cluster ───────────────────────
            Rectangle {
                id: rightPill
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: Theme.pillHeight
                implicitWidth: rightRow.implicitWidth + 18
                topLeftRadius: Theme.radiusPill; topRightRadius: Theme.radiusPill
                bottomLeftRadius: root.panelOpen ? 0 : Theme.radiusPill
                bottomRightRadius: root.panelOpen ? 0 : Theme.radiusPill
                Behavior on bottomLeftRadius  { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                Behavior on bottomRightRadius { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, Colors.pillBgAlpha)
                border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.pillBorderAlpha)
                border.width: 1

                HoverHandler { id: rightPillHover }

                RowLayout {
                    id: rightRow
                    anchors.centerIn: parent; spacing: 10

                    // System tray
                    SystemTrayWidget {
                        id: tray
                        Layout.alignment: Qt.AlignVCenter
                        visible: SystemTray.items.values.length > 0
                    }

                    Rectangle {
                        visible: tray.visible
                        width: 1; height: 14; radius: 1
                        color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.3)
                    }

                    // WiFi
                    Item {
                        implicitWidth: wifiIconRow.implicitWidth
                        implicitHeight: wifiIconRow.implicitHeight
                        HoverHandler { onHoveredChanged: if (hovered) { ControlState.activeScreen = root.screen.name; ControlState.rightPanel = "wifi"; root.pinnedOpen = false } }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.pinnedOpen && ControlState.rightPanel === "wifi") { root.pinnedOpen = false; ControlState.rightPanel = "none" }
                                else { ControlState.activeScreen = root.screen.name; ControlState.rightPanel = "wifi"; root.pinnedOpen = true }
                            }
                        }
                        Row {
                            id: wifiIconRow; spacing: Theme.spacingTight
                            Text {
                                text: {
                                    if (NetworkState.connType === "ethernet") return "󰈀"
                                    if (!NetworkState.wifiEnabled) return "󰤯"
                                    if (NetworkState.connType === "wifi") return NetworkState.signalIcon(NetworkState.signal)
                                    return "󰤭"
                                }
                                color: NetworkState.connType !== "none" ? Colors.text : Colors.textMuted
                                font.pixelSize: Theme.fontLarge; font.family: Theme.fontFamily
                            }
                            Text {
                                visible: NetworkState.anyVpnActive
                                text: "󰦝"
                                color: Colors.success
                                font.pixelSize: Theme.fontMedium; font.family: Theme.fontFamily
                            }
                        }
                    }

                    // Bluetooth
                    Item {
                        implicitWidth: btIconText.implicitWidth
                        implicitHeight: btIconText.implicitHeight
                        HoverHandler { onHoveredChanged: if (hovered) { ControlState.activeScreen = root.screen.name; ControlState.rightPanel = "bluetooth"; root.pinnedOpen = false } }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.pinnedOpen && ControlState.rightPanel === "bluetooth") { root.pinnedOpen = false; ControlState.rightPanel = "none" }
                                else { ControlState.activeScreen = root.screen.name; ControlState.rightPanel = "bluetooth"; root.pinnedOpen = true }
                            }
                        }
                        Text {
                            id: btIconText
                            text: {
                                const a = Bluetooth.defaultAdapter
                                if (!a || !a.enabled) return "󰂲"
                                for (const d of Bluetooth.devices.values) {
                                    if (d.connected) return "󰂱"
                                }
                                return "󰂯"
                            }
                            color: {
                                const a = Bluetooth.defaultAdapter
                                if (!a || !a.enabled) return Colors.textMuted
                                for (const d of Bluetooth.devices.values) {
                                    if (d.connected) return Colors.success
                                }
                                return Colors.text
                            }
                            font.pixelSize: Theme.fontLarge; font.family: Theme.fontFamily
                        }
                    }

                    Rectangle { width: 1; height: 14; radius: 1; color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.3) }

                    // Audio
                    Item {
                        id: audioCluster
                        implicitWidth: audioRow.implicitWidth
                        implicitHeight: audioRow.implicitHeight
                        HoverHandler { onHoveredChanged: if (hovered) { ControlState.activeScreen = root.screen.name; ControlState.rightPanel = "audio"; root.pinnedOpen = false } }
                        Row { id: audioRow; spacing: Theme.spacingTight
                            Text {
                                text: !AudioState.sinkReady ? "󰕿" : AudioState.muted ? "󰖁" : AudioState.volume > 0.5 ? "󰕾" : "󰖀"
                                color: AudioState.muted ? Colors.textMuted : Colors.text
                                font.pixelSize: Theme.fontLarge; font.family: Theme.fontFamily
                            }
                            Text {
                                visible: AudioState.sinkReady && !AudioState.muted
                                text: Math.round(AudioState.volume * 100) + "%"
                                color: Colors.text
                                font.pixelSize: Theme.fontMedium; font.family: Theme.fontFamily
                            }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.pinnedOpen && ControlState.rightPanel === "audio") { root.pinnedOpen = false; ControlState.rightPanel = "none" }
                                else { ControlState.activeScreen = root.screen.name; ControlState.rightPanel = "audio"; root.pinnedOpen = true }
                            }
                            onWheel: ev => {
                                const delta = ev.angleDelta.y > 0 ? 0.05 : -0.05
                                AudioState.setVolume(AudioState.volume + delta)
                            }
                        }
                    }

                    Rectangle { width: 1; height: 14; radius: 1; color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.3) }

                    // Battery
                    Item {
                        id: batteryCluster
                        implicitWidth: batRow.implicitWidth
                        implicitHeight: batRow.implicitHeight
                        HoverHandler { onHoveredChanged: if (hovered) { ControlState.activeScreen = root.screen.name; ControlState.rightPanel = "battery"; root.pinnedOpen = false } }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.pinnedOpen && ControlState.rightPanel === "battery") { root.pinnedOpen = false; ControlState.rightPanel = "none" }
                                else { ControlState.activeScreen = root.screen.name; ControlState.rightPanel = "battery"; root.pinnedOpen = true }
                            }
                        }
                        property var bat: {
                            for (const d of UPower.devices.values) {
                                if (d.isLaptopBattery && d.ready && d.percentage > 0.01) return d
                            }
                            const dd = UPower.displayDevice
                            return (dd && dd.ready && dd.percentage > 0.01) ? dd : null
                        }
                        // Bypass = on AC but not charging (battery at threshold, AC powers system directly).
                        // UPower's state property is unreliable here (reports Charging even when sysfs says Not charging),
                        // so read /sys/class/power_supply/BAT0/status directly.
                        property string batStatus: ""
                        property bool bypass: batteryCluster.batStatus === "Not charging"
                        FileView {
                            path: "/sys/class/power_supply/BAT0/status"
                            watchChanges: true
                            onFileChanged: reload()
                            onLoaded: batteryCluster.batStatus = text().trim()
                        }
                        Row { id: batRow; spacing: Theme.spacingTight
                            Text {
                                visible: batteryCluster.bypass
                                text: "󰒃"
                                color: Colors.accent
                                font.pixelSize: Theme.fontLarge; font.family: Theme.fontFamily
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: !batteryCluster.bat ? "󰂑" : batteryCluster.bat.state === 1 ? "󰂋" : batteryCluster.bat.percentage < 0.25 ? "󰁻" : "󰁽"
                                color: batteryCluster.bat?.state === 1 ? Colors.success : batteryCluster.bat?.percentage < 0.20 ? Colors.error : Colors.text
                                font.pixelSize: Theme.fontLarge; font.family: Theme.fontFamily
                            }
                            Text {
                                text: batteryCluster.bat ? Math.round(batteryCluster.bat.percentage * 100) + "%" : "--"
                                color: Colors.textMuted
                                font.pixelSize: Theme.fontMedium; font.family: Theme.fontFamily
                            }
                        }
                    }

                    Rectangle { width: 1; height: 14; radius: 1; color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.3) }

                    // Clock
                    Item {
                        implicitWidth: clockRow.implicitWidth
                        implicitHeight: clockRow.implicitHeight
                        HoverHandler { onHoveredChanged: if (hovered) { ControlState.activeScreen = root.screen.name; ControlState.rightPanel = "clock"; root.pinnedOpen = false } }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.pinnedOpen && ControlState.rightPanel === "clock") { root.pinnedOpen = false; ControlState.rightPanel = "none" }
                                else { ControlState.activeScreen = root.screen.name; ControlState.rightPanel = "clock"; root.pinnedOpen = true }
                            }
                        }
                        Clock { id: clockRow }
                    }

                    Rectangle { width: 1; height: 14; radius: 1; color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.3) }

                    // Idle inhibitor (caffeine)
                    Item {
                        implicitWidth: caffeineIcon.implicitWidth
                        implicitHeight: caffeineIcon.implicitHeight
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: ControlState.idleInhibited = !ControlState.idleInhibited
                        }
                        Text {
                            id: caffeineIcon
                            text: ControlState.idleInhibited ? "󰛊" : "󰒲"
                            color: ControlState.idleInhibited ? Colors.accent : Colors.textMuted
                            font.pixelSize: Theme.fontLarge; font.family: Theme.fontFamily
                            Behavior on color { ColorAnimation { duration: Theme.durHover } }
                        }
                    }

                    Rectangle { width: 1; height: 14; radius: 1; color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.3) }

                    // Notification bell
                    Item {
                        implicitWidth: bellRow.implicitWidth + 4
                        implicitHeight: bellRow.implicitHeight
                        HoverHandler { onHoveredChanged: if (hovered) { ControlState.activeScreen = root.screen.name; ControlState.rightPanel = "notif"; root.pinnedOpen = false } }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.pinnedOpen && ControlState.rightPanel === "notif") { root.pinnedOpen = false; ControlState.rightPanel = "none" }
                                else { ControlState.activeScreen = root.screen.name; ControlState.rightPanel = "notif"; root.pinnedOpen = true }
                            }
                        }
                        Row { id: bellRow; spacing: Theme.spacingTight
                            Text {
                                text: ControlState.rightPanel === "notif" ? "󰂞" : NotifState.unreadCount > 0 ? "󰂚" : "󰂜"
                                color: Colors.text
                                font.pixelSize: 14; font.family: Theme.fontFamily
                            }
                            Rectangle {
                                visible: NotifState.unreadCount > 0
                                width: badgeText.width + 6; height: 14; radius: 7
                                color: Colors.accent
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    id: badgeText
                                    anchors.centerIn: parent
                                    text: NotifState.unreadCount > 9 ? "9+" : String(NotifState.unreadCount)
                                    color: Colors.bg; font.pixelSize: Theme.fontTiny; font.bold: true
                                    font.family: Theme.fontFamily
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
