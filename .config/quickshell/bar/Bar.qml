import QtQuick
import QtQuick.Layouts
import ".."
import "popups"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import Quickshell.Networking
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

    // Corners flat while ANY popup is visible
    property bool panelOpen: rightPanelPopup.popupVisible || toastPopup.toastVisible || mprisPopup.popupVisible || controlCenter.popupVisible
    // Which panel (if any) is click-pinned. "" = no pin (hover-only).
    // Scoping by name prevents one pill's pin leaking onto another pill's panel.
    property string pinnedPanel: ""
    readonly property bool isPinned: pinnedPanel.length > 0

    // Close on ToplevelManager focus change (click elsewhere).
    // Skip if user is interacting with the bar's own popups: clicking a pill
    // or hovering its panel briefly drops the active toplevel (layer-shell
    // focus grant), which would otherwise race the click handler and cause
    // pin-on-click to flicker / require multiple attempts.
    Connections {
        target: ToplevelManager
        function onActiveToplevelChanged() {
            if (root.isPinned) return
            if (rightPanelPopup.keyboardActive || mprisPopup.keyboardActive) return
            if (rightPillHover.hovered || mprisPillHover.hovered) return
            if (rightPanelPopup.panelHovered || mprisPopup.panelHovered) return
            ControlState.rightPanel = "none"
            if (ControlState.controlCenterOpen)
                ControlState.closeControlCenter()
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
        pinnedPanel: root.pinnedPanel
        pillHovered: rightPillHover.hovered
        onPinnedClosed: root.pinnedPanel = ""
    }

    ToastPopup {
        id: toastPopup
        bar: root
        anchorItem: rightPill
    }

    MprisPopup {
        id: mprisPopup
        bar: root
        anchorItem: mprisPill
        pinnedPanel: root.pinnedPanel
        pillHovered: mprisPillHover.hovered
        onPinnedClosed: root.pinnedPanel = ""
    }

    ControlCenter {
        id: controlCenter
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
                color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, Theme.elevation.e1TintAlpha)
                border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Theme.elevation.e1BorderAlpha)
                border.width: 1
                Behavior on implicitWidth { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutQuad } }
                Workspaces { id: workspacesRow; anchors.centerIn: parent; output: root.screen ? root.screen.name : "" }
            }

            // ── Center pill: window title ────────────────────────
            Rectangle {
                Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                implicitHeight: Theme.pillHeight; radius: Theme.radiusPill
                color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, Theme.elevation.e1TintAlpha * 0.6)
                border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Theme.elevation.e1BorderAlpha * 0.7)
                border.width: 1

                WindowTitle {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 12 }
                }
            }

            // ── MPRIS pill ───────────────────────────────────────
            // Visible while ANY player exists (not just playing) — pause must
            // not collapse the pill. Bottom corners flatten only when the
            // MPRIS popup is open on this screen, mirroring rightPill.
            // Width grows to a floor when own panel open so the wider panel
            // body aligns cleanly with the pill edges.
            Rectangle {
                id: mprisPill
                Layout.alignment: Qt.AlignVCenter
                readonly property bool show: MprisState.hasAny
                readonly property int panelMinWidth: 240
                readonly property real targetWidth: ownPanelOpen
                    ? Math.max(mediaContent.implicitWidth + 24, panelMinWidth)
                    : mediaContent.implicitWidth + 24
                readonly property bool ownPanelOpen: mprisPopup.popupVisible
                    && ControlState.rightPanel === "mpris"
                    && root.screen && root.screen.name === ControlState.activeScreen

                implicitHeight: Theme.pillHeight
                implicitWidth: show ? targetWidth : 0
                topLeftRadius: Theme.radiusPill; topRightRadius: Theme.radiusPill
                bottomLeftRadius: ownPanelOpen ? 0 : Theme.radiusPill
                bottomRightRadius: ownPanelOpen ? 0 : Theme.radiusPill
                Behavior on bottomLeftRadius  { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                Behavior on bottomRightRadius { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, Theme.elevation.e1TintAlpha)
                border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Theme.elevation.e1BorderAlpha)
                border.width: 1
                opacity: show ? 1 : 0
                clip: true
                visible: implicitWidth > 1
                Behavior on implicitWidth { NumberAnimation { duration: Theme.durSlide; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutCubic } }

                HoverHandler { id: mprisPillHover }

                MediaPlayer {
                    id: mediaContent
                    bar: root
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 12 }
                }
            }

            // ── Perf pill: CPU% + sparkline ──────────────────────
            // Hidden by default. Mod+H toggles ControlState.perfPillVisible.
            // Click opens PerfPanel (top-edge slide-down).
            PerfPill { id: perfPill; bar: root }

            // ── Right pill: status cluster ───────────────────────
            Rectangle {
                id: rightPill
                Layout.alignment: Qt.AlignVCenter
                // Flatten only when the right-cluster popup is what's open
                // (mpris popup opens elsewhere → don't flatten this pill).
                readonly property bool ownPanelOpen: rightPanelPopup.popupVisible || toastPopup.toastVisible
                implicitHeight: Theme.pillHeight
                implicitWidth: rightRow.implicitWidth + 18
                topLeftRadius: Theme.radiusPill; topRightRadius: Theme.radiusPill
                bottomLeftRadius: ownPanelOpen ? 0 : Theme.radiusPill
                bottomRightRadius: ownPanelOpen ? 0 : Theme.radiusPill
                Behavior on bottomLeftRadius  { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                Behavior on bottomRightRadius { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, Theme.elevation.e1TintAlpha)
                border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Theme.elevation.e1BorderAlpha)
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

                    BarDivider { visible: tray.visible }

                    // WiFi
                    BarPillButton {
                        panel: "wifi"; bar: root
                        clickOnly: true
                        onActivated: { ControlState.activeScreen = root.screen.name; ControlState.openControlCenter("wifi") }
                        Row {
                            spacing: Theme.spacingTight
                            Text {
                                text: {
                                    if (NetUtils.wiredConnected) return "󰈀"
                                    if (!Networking.wifiEnabled) return "󰤯"
                                    if (NetUtils.activeWifi) return NetUtils.signalIcon(NetUtils.activeWifi.signalStrength)
                                    return "󰤭"
                                }
                                color: (NetUtils.wiredConnected || NetUtils.activeWifi) ? Colors.text : Colors.textMuted
                                font.pixelSize: Theme.fontLarge; font.family: Theme.fontFamily
                            }
                            Text {
                                visible: VpnState.anyVpnActive
                                text: "󰦝"
                                color: Colors.success
                                font.pixelSize: Theme.fontMedium; font.family: Theme.fontFamily
                            }
                        }
                    }

                    // Bluetooth
                    BarPillButton {
                        panel: "bluetooth"; bar: root
                        clickOnly: true
                        onActivated: { ControlState.activeScreen = root.screen.name; ControlState.openControlCenter("bluetooth") }
                        Text {
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

                    BarDivider {}

                    // Audio (scroll-wheel adjusts volume)
                    BarPillButton {
                        id: audioCluster
                        panel: "audio"; bar: root
                        clickOnly: true
                        onActivated: { ControlState.activeScreen = root.screen.name; ControlState.openControlCenter("") }
                        onWheelEvent: ev => {
                            const delta = ev.angleDelta.y > 0 ? 0.05 : -0.05
                            AudioState.setVolume(AudioState.volume + delta)
                        }

                        Row {
                            spacing: Theme.spacingTight
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
                    }

                    BarDivider {}

                    // Battery
                    BarPillButton {
                        id: batteryCluster
                        panel: "battery"; bar: root
                        clickOnly: true
                        onActivated: { ControlState.activeScreen = root.screen.name; ControlState.openControlCenter("") }

                        property var bat: {
                            for (const d of UPower.devices.values) {
                                if (d.isLaptopBattery && d.ready && d.percentage > 0.01) return d
                            }
                            const dd = UPower.displayDevice
                            return (dd && dd.ready && dd.percentage > 0.01) ? dd : null
                        }
                        // Bypass = on AC but not charging (battery at threshold, AC powers system directly).
                        // UPower's state property is unreliable here (reports Charging even when sysfs says Not charging),
                        // so read sysfs status directly. Path derived from UPower nativePath to support BAT1/etc.
                        property string batStatus: ""
                        property bool bypass: batteryCluster.batStatus === "Not charging"
                        FileView {
                            path: batteryCluster.bat ? "/sys/class/power_supply/" + batteryCluster.bat.nativePath + "/status" : ""
                            watchChanges: true
                            onFileChanged: reload()
                            onLoaded: batteryCluster.batStatus = text().trim()
                        }
                        Row {
                            spacing: Theme.spacingTight
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

                    BarDivider {}

                    // Clock
                    BarPillButton {
                        panel: "clock"; bar: root
                        Clock {}
                    }

                    BarDivider {}

                    // Idle inhibitor (caffeine) — toggle, no panel
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
                            Behavior on color { ColorAnimation { duration: Theme.durFast } }
                        }
                    }

                    BarDivider {}

                    // Notification bell
                    BarPillButton {
                        panel: "notif"; bar: root
                        horizontalPadding: 2
                        Row {
                            spacing: Theme.spacingTight
                            Text {
                                text: ControlState.rightPanel === "notif" ? "󰂞" : NotifState.unreadCount > 0 ? "󰂚" : "󰂜"
                                color: Colors.text
                                font.pixelSize: Theme.fontLarge; font.family: Theme.fontFamily
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

                    BarDivider {}
                    ControlCenterButton { bar: root; Layout.alignment: Qt.AlignVCenter }
                }
            }
        }
    }
}
