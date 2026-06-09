import QtQuick
import "../.."
import "../../components"
import "../panels"
import Quickshell
import Quickshell.Wayland
import Quickshell.Networking
import Quickshell.Bluetooth

// Click-opened control center anchored to the ControlCenterButton. Mirrors
// RightPanelPopup's blur + slide. Body: quick tiles + sliders + now-playing.
PopupWindow {
    id: root
    property var bar
    property Item anchorItem

    readonly property bool _onActiveScreen: bar && bar.screen
        && bar.screen.name === ControlState.activeScreen
    property bool popupVisible: false
    // True while the cursor is over the panel — the bar checks this so moving
    // toward the floating panel (across the gap) doesn't close it.
    readonly property bool panelHovered: ccHover.hovered

    visible: popupVisible
    color: "transparent"
    implicitWidth: 360
    // Window includes the gap strip above the glass so its hover area reaches up
    // to the bar — no dead zone between the CC button and the floating panel.
    readonly property int ccGap: 6
    implicitHeight: panelOuter.implicitHeight + ccGap

    // Hover the whole window (gap strip + panel); the bar guards on panelHovered.
    HoverHandler { id: ccHover }

    BackgroundEffect.blurRegion: Region {
        x: panelOuter.x; y: panelOuter.y
        width: panelOuter.width; height: panelOuter.implicitHeight
        topLeftRadius: Theme.radiusLarge; topRightRadius: Theme.radiusLarge
        bottomLeftRadius: Theme.radiusLarge; bottomRightRadius: Theme.radiusLarge
    }

    // Floating panel: right-aligned to the cluster. Window touches the bar; the
    // visual gap is the transparent strip above the glass inside the window.
    anchor.window: bar
    anchor.rect.x: anchorItem ? anchorItem.x + anchorItem.width - 360 : 0
    anchor.rect.y: bar ? bar.implicitHeight : 0
    anchor.rect.width: 360
    anchor.rect.height: 0

    Connections {
        target: ControlState
        function onControlCenterOpenChanged() {
            if (ControlState.controlCenterOpen && root._onActiveScreen) {
                root.popupVisible = true
                panelOuter.y = root.ccGap - 8
                panelOuter.opacity = 0
                appearAnim.start()
            } else if (root.popupVisible) {
                disappearAnim.start()
            }
        }
    }

    // Floating drop-in: short slide + fade (not a bar-attached unroll).
    ParallelAnimation {
        id: appearAnim
        NumberAnimation { target: panelOuter; property: "y"; to: root.ccGap
            duration: Theme.durNormal; easing.type: Easing.OutCubic }
        NumberAnimation { target: panelOuter; property: "opacity"; to: 1
            duration: Theme.durNormal; easing.type: Easing.OutCubic }
    }
    SequentialAnimation {
        id: disappearAnim
        ParallelAnimation {
            NumberAnimation { target: panelOuter; property: "y"; to: root.ccGap - 8
                duration: Theme.durFast; easing.type: Easing.InCubic }
            NumberAnimation { target: panelOuter; property: "opacity"; to: 0
                duration: Theme.durFast; easing.type: Easing.InCubic }
        }
        ScriptAction { script: root.popupVisible = false }
    }

    Rectangle {
        id: panelOuter
        y: root.ccGap
        width: 360
        implicitHeight: body.implicitHeight + 2 * Theme.panelPadding
        radius: Theme.radiusLarge
        color: "transparent"
        clip: true

        // Floating glass: fully rounded, full border (all four corners traced).
        GlassSurface {
            anchors.fill: parent
            level: "e3"; radius: Theme.radiusLarge
        }

        MouseArea { anchors.fill: parent }
        Item {
            focus: root.popupVisible
            Keys.onEscapePressed: ControlState.closeControlCenter()
        }

        Item {
            id: body
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.panelPadding }
            readonly property bool detail: ControlState.ccSection !== ""
            implicitHeight: detail ? detailLayer.implicitHeight : mainLayer.implicitHeight
            Behavior on implicitHeight { NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutCubic } }

            Column {
                id: mainLayer
                width: parent.width
                spacing: Theme.spacingNormal
                opacity: body.detail ? 0 : 1
                x: body.detail ? -20 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutCubic } }
                Behavior on x { NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutCubic } }

                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: Theme.spacingSmall
                    rowSpacing: Theme.spacingSmall
                    readonly property real cellW: (width - Theme.spacingSmall) / 2

                    GlassTile {
                        width: parent.cellW
                        icon: Networking.wifiEnabled ? "󰖩" : "󰖪"
                        label: "Wi-Fi"
                        sub: Networking.wifiEnabled ? (NetUtils.activeWifi ? NetUtils.activeWifi.name : "On") : "Off"
                        on: Networking.wifiEnabled
                        onClicked: Networking.wifiEnabled = !Networking.wifiEnabled

                        Text {
                            text: "›"
                            color: Colors.textMuted
                            font.pixelSize: Theme.fontMedium; font.family: Theme.fontFamily
                            anchors { top: parent.top; right: parent.right; margins: Theme.spacingSmall }
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ControlState.ccSection = "wifi"
                            }
                        }
                    }
                    GlassTile {
                        width: parent.cellW
                        icon: "󰂯"
                        label: "Bluetooth"
                        on: !!(Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled)
                        sub: {
                            if (!Bluetooth.defaultAdapter || !Bluetooth.defaultAdapter.enabled) return "Off"
                            for (const d of Bluetooth.devices.values) if (d.connected) return d.name
                            return "On"
                        }
                        onClicked: if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled

                        Text {
                            text: "›"
                            color: Colors.textMuted
                            font.pixelSize: Theme.fontMedium; font.family: Theme.fontFamily
                            anchors { top: parent.top; right: parent.right; margins: Theme.spacingSmall }
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ControlState.ccSection = "bluetooth"
                            }
                        }
                    }
                    GlassTile {
                        width: parent.cellW
                        icon: NotifState.dnd ? "󰂛" : "󰂚"
                        label: "Do Not Disturb"
                        on: NotifState.dnd
                        onClicked: NotifState.dnd = !NotifState.dnd
                    }
                    GlassTile {
                        width: parent.cellW
                        icon: ControlState.idleInhibited ? "󰛊" : "󰒲"
                        label: "Caffeine"
                        on: ControlState.idleInhibited
                        onClicked: ControlState.idleInhibited = !ControlState.idleInhibited
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingNormal

                    Row {
                        width: parent.width; spacing: Theme.spacingNormal
                        Text {
                            text: AudioState.muted ? "󰖁" : "󰕾"; color: Colors.text
                            font.pixelSize: 16; font.family: Theme.fontFamily
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: AudioState.toggleMute() }
                        }
                        GlassSlider {
                            width: parent.width - 28
                            anchors.verticalCenter: parent.verticalCenter
                            value: AudioState.volume; max: 1.0; active: !AudioState.muted
                            onMoved: v => AudioState.setVolume(v)
                        }
                    }
                    Row {
                        width: parent.width; spacing: Theme.spacingNormal
                        Text {
                            text: AudioState.micMuted ? "󰍭" : "󰍬"; color: Colors.text
                            font.pixelSize: 16; font.family: Theme.fontFamily
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: AudioState.toggleMicMute() }
                        }
                        GlassSlider {
                            width: parent.width - 28
                            anchors.verticalCenter: parent.verticalCenter
                            value: AudioState.micVolume; max: 1.0; active: !AudioState.micMuted
                            onMoved: v => AudioState.setMicVolume(v)
                        }
                    }
                    Row {
                        width: parent.width; spacing: Theme.spacingNormal
                        visible: BrightnessState.available
                        Text {
                            text: "󰃟"; color: Colors.text
                            font.pixelSize: 16; font.family: Theme.fontFamily
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        GlassSlider {
                            width: parent.width - 28
                            anchors.verticalCenter: parent.verticalCenter
                            value: BrightnessState.value; max: 1.0
                            onMoved: v => BrightnessState.set(v)
                        }
                    }
                }

                GlassCard {
                    width: parent.width
                    visible: MprisState.hasAny
                    MprisPanel { anchors { left: parent.left; right: parent.right } }
                }
            }

            Column {
                id: detailLayer
                width: parent.width
                spacing: Theme.spacingNormal
                opacity: body.detail ? 1 : 0
                x: body.detail ? 0 : 20
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutCubic } }
                Behavior on x { NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutCubic } }

                Row {
                    width: parent.width; spacing: Theme.spacingSmall
                    Text {
                        text: "‹"; color: Colors.accent; font.pixelSize: 18; font.family: Theme.fontFamily
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: ControlState.ccSection = "" }
                    }
                    Text {
                        text: ControlState.ccSection === "wifi" ? "Wi-Fi" : "Bluetooth"
                        color: Colors.text; font.pixelSize: Theme.fontMedium; font.bold: true
                        font.family: Theme.fontFamily; anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Loader {
                    width: parent.width
                    active: body.detail
                    sourceComponent: ControlState.ccSection === "wifi" ? wifiComp
                        : ControlState.ccSection === "bluetooth" ? btComp : null
                }
                Component { id: wifiComp; WifiPanel {} }
                Component { id: btComp; BluetoothPanel {} }
            }
        }
    }
}
