import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
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

    property bool panelOpen: toastPopup.toastVisible || mprisPopup.popupVisible || controlCenter.popupVisible
    // Which panel (if any) is click-pinned. "" = no pin (hover-only).
    property string pinnedPanel: ""
    readonly property bool isPinned: pinnedPanel.length > 0

    // Native compositor blur behind the whole bar strip so the subtle glass
    // tint stays legible over any wallpaper (real macOS-menubar glass).
    BackgroundEffect.blurRegion: Region {
        x: 0; y: 0; width: root.width; height: root.height
        topLeftRadius: Theme.radiusMedium; topRightRadius: Theme.radiusMedium
        bottomLeftRadius: Theme.radiusMedium; bottomRightRadius: Theme.radiusMedium
    }

    // Close on ToplevelManager focus change (click elsewhere).
    // Skip if the user is interacting with the bar's own popups.
    Connections {
        target: ToplevelManager
        function onActiveToplevelChanged() {
            if (root.isPinned) return
            if (mprisPopup.keyboardActive) return
            if (mprisPopup.panelHovered) return
            ControlState.rightPanel = "none"
            // NB: the Control Center intentionally does NOT close on focus change
            // — you can alt-tab to a password manager, copy, and come back. It
            // closes only via its button toggle or Escape.
        }
    }

    // Idle inhibitor — systemd-inhibit child process lives while inhibited
    Process {
        id: idleInhibitProc
        command: ["systemd-inhibit", "--what=idle", "--who=quickshell", "--why=user-toggled", "sleep", "infinity"]
        running: ControlState.idleInhibited
    }

    // Clicking outside the Control Center dismisses it. This transparent top
    // layer also owns Escape when no control inside the popup has focus.
    PanelWindow {
        id: controlCenterDismissLayer
        screen: root.screen
        visible: ControlState.controlCenterOpen
            && root.screen && root.screen.name === ControlState.activeScreen
        color: "transparent"
        exclusiveZone: 0
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.namespace: "qs-control-dismiss"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        MouseArea {
            anchors.fill: parent
            onClicked: ControlState.closeControlCenter()
        }
        Item {
            anchors.fill: parent
            focus: controlCenterDismissLayer.visible
            Keys.onEscapePressed: ControlState.closeControlCenter()
        }
    }

    // ── Popups ───────────────────────────────────────────────────
    // (Notifications history + calendar now live in the Control Center;
    // the old RightPanelPopup dropdown is retired.)
    ToastPopup {
        id: toastPopup
        bar: root
        anchorItem: rightCluster
    }

    MprisPopup {
        id: mprisPopup
        bar: root
        anchorItem: mprisItem
        pinnedPanel: root.pinnedPanel
        // Live label-hover: leaving the label without entering the panel must
        // arm the close timer (a constant `false` here left the panel stuck open).
        pillHovered: mediaContent.labelHovered
        onPinnedClosed: root.pinnedPanel = ""
    }

    ControlCenter {
        id: controlCenter
        bar: root
        anchorItem: rightCluster
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
                NumberAnimation { target: barContent; property: "opacity"; from: 0; to: 1; duration: Theme.durEnter; easing.type: Easing.OutCubic }
                NumberAnimation { target: barContent; property: "y"; from: -10; to: 0; duration: Theme.durEnter; easing.type: Easing.OutCubic }
            }
        }

        // Full-width bar glass: one flat menubar strip, no per-item chrome.
        GlassSurface {
            anchors.fill: parent
            level: "e1"
            radius: Theme.radiusMedium
        }

        RowLayout {
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom }
            anchors.leftMargin: Theme.spacingLarge
            anchors.rightMargin: Theme.spacingSmall
            spacing: Theme.spacingNormal

            // ── Left: workspaces (flat) ──────────────────────────
            Workspaces {
                id: workspacesRow
                Layout.alignment: Qt.AlignVCenter
                output: root.screen ? root.screen.name : ""
            }

            // ── Center: window title (flat, takes the slack) ─────
            WindowTitle {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: Theme.spacingSmall
                Layout.rightMargin: Theme.spacingSmall
            }

            // ── MPRIS (flat) ─────────────────────────────────────
            // Visible while ANY player exists; pause must not collapse it.
            Item {
                id: mprisItem
                Layout.alignment: Qt.AlignVCenter
                readonly property bool show: MprisState.hasAny && SettingsState.showMediaInBar
                implicitHeight: Theme.pillHeight
                implicitWidth: show ? mediaContent.implicitWidth + 12 : 0
                opacity: show ? 1 : 0
                clip: true
                visible: implicitWidth > 1
                Behavior on implicitWidth { NumberAnimation { duration: Theme.durSlide; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutCubic } }

                MediaPlayer {
                    id: mediaContent
                    bar: root
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                }
            }

            // ── Perf pill: CPU% + sparkline (toggle via Mod+Shift+H) ─
            PerfPill { id: perfPill; bar: root }

            // Compact Live Activity: persistent recording state + elapsed time.
            LiveActivityPill { Layout.alignment: Qt.AlignVCenter }

            // ── Right: status cluster (flat glyphs, hover chips) ─
            Row {
                id: rightCluster
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                // System tray
                Item {
                    visible: SettingsState.showTray && SystemTray.items.values.length > 0
                    width: visible ? tray.implicitWidth + Theme.spacingSmall : 0
                    height: Theme.hitTarget
                    SystemTrayWidget {
                        id: tray
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    }
                }

                // Caffeine belongs with connectivity/status controls, not tray apps.
                BarPillButton {
                    visible: ControlState.idleInhibited
                    accessibleName: "Disable caffeine"
                    onActivated: ControlState.idleInhibited = false
                    Text {
                        text: "󰛊"; color: Colors.accent
                        font.pixelSize: Theme.fontLarge; font.family: Theme.fontIcon
                    }
                }

                // WiFi / wired
                BarPillButton {
                    accessibleName: "Network settings"
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
                            font.pixelSize: Theme.fontLarge; font.family: Theme.fontIcon
                        }
                        Text {
                            visible: VpnState.anyVpnActive
                            text: "󰦝"
                            color: Colors.accent
                            font.pixelSize: Theme.fontMedium; font.family: Theme.fontIcon
                        }
                    }
                }

                // Bluetooth — adaptive: hidden unless the adapter is on
                BarPillButton {
                    visible: !!(Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled)
                    accessibleName: "Bluetooth settings"
                    onActivated: { ControlState.activeScreen = root.screen.name; ControlState.openControlCenter("bluetooth") }
                    Text {
                        text: {
                            for (const d of Bluetooth.devices.values)
                                if (d.connected) return "󰂱"
                            return "󰂯"
                        }
                        color: {
                            for (const d of Bluetooth.devices.values)
                                if (d.connected) return Colors.accent
                            return Colors.text
                        }
                        font.pixelSize: Theme.fontLarge; font.family: Theme.fontIcon
                    }
                }

                // Audio (scroll adjusts volume) — glyph only, macOS-style
                BarPillButton {
                    id: audioCluster
                    accessibleName: AudioState.muted ? "Audio muted" : "Volume " + Math.round(AudioState.volume * 100) + "%"
                    onActivated: { ControlState.activeScreen = root.screen.name; ControlState.openControlCenter("") }
                    onWheelEvent: ev => {
                        const delta = ev.angleDelta.y > 0 ? 0.05 : -0.05
                        AudioState.setVolume(AudioState.volume + delta)
                    }
                    Text {
                        text: !AudioState.sinkReady ? "󰕿" : AudioState.muted ? "󰖁" : AudioState.volume > 0.5 ? "󰕾" : "󰖀"
                        color: AudioState.muted ? Colors.textMuted : Colors.text
                        font.pixelSize: Theme.fontLarge; font.family: Theme.fontIcon
                    }
                }

                // Battery — glyph + %, click opens the CC battery detail
                // (consistent with the WiFi / Bluetooth pills).
                BarPillButton {
                    id: batteryCluster
                    accessibleName: "Battery settings"
                    visible: !!bat
                    onActivated: { ControlState.activeScreen = root.screen.name; ControlState.openControlCenter("battery") }

                    property var bat: {
                        for (const d of UPower.devices.values) {
                            if (d.isLaptopBattery && d.ready && d.percentage > 0.01) return d
                        }
                        const dd = UPower.displayDevice
                        return (dd && dd.ready && dd.percentage > 0.01) ? dd : null
                    }
                    readonly property int pct: bat ? Math.round(bat.percentage * 100) : 0
                    readonly property bool charging: !!bat && bat.state === 1

                    Row {
                        spacing: Theme.spacingTight
                        // Positioner children can't anchor — center each Text
                        // inside a fixed pill-height line instead.
                        Text {
                            text: batteryCluster.charging ? "󰂄" : Theme.batteryGlyph(batteryCluster.pct)
                            color: batteryCluster.charging ? Colors.accent
                                : batteryCluster.pct < 20 ? Colors.error : Colors.text
                            font.pixelSize: Theme.fontLarge; font.family: Theme.fontIcon
                            height: Theme.pillHeight; verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            text: batteryCluster.pct + "%"
                            color: Colors.textMuted
                            font.pixelSize: Theme.fontMedium; font.family: Theme.fontFamily
                            font.features: { "tnum": 1 }
                            height: Theme.pillHeight; verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                // Clock + Control Center opener (time + CC icon). While there are
                // unread notifications, a comet orbits the button (replaces a count).
                Item {
                    id: clockBtn
                    implicitWidth: clockRow.implicitWidth + 14
                    // Match sibling hit targets so Row does not top-align this
                    // shorter item inside the status cluster.
                    implicitHeight: Theme.hitTarget

                    Rectangle {
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                        height: Theme.pillHeight
                        radius: Theme.radiusSmall
                        color: Qt.rgba(1, 1, 1, clockHover.hovered ? Theme.hoverBrightness : 0)
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                    }

                    Row {
                        id: clockRow
                        anchors.centerIn: parent
                        spacing: Theme.spacingSmall
                        Clock { anchors.verticalCenter: parent.verticalCenter }
                        // DND indicator — without it the "toasts are off" state
                        // is invisible outside the Control Center.
                        Text {
                            visible: NotifState.dnd
                            text: "󰂛"
                            color: Colors.textMuted
                            font.pixelSize: Theme.fontMedium; font.family: Theme.fontIcon
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Item {
                            width: 30; height: 25
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                anchors.centerIn: parent
                                text: "󰕮"
                                color: ControlState.controlCenterOpen ? Colors.accent : Colors.textMuted
                                font.pixelSize: Theme.fontLarge; font.family: Theme.fontIcon
                                Behavior on color { ColorAnimation { duration: Theme.durFast } }
                            }
                            NotifOrbit {
                                anchors.fill: parent
                                visible: NotifState.unreadCount > 0 && !NotifState.dnd
                                running: visible
                            }
                        }
                    }

                    HoverHandler { id: clockHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (ControlState.controlCenterOpen) {
                                if (ControlState.ccSection !== "") ControlState.ccSection = ""
                                else ControlState.closeControlCenter()
                                return
                            }
                            ControlState.activeScreen = root.screen.name
                            ControlState.openControlCenter("")
                        }
                    }
                }

            }
        }
    }
}
