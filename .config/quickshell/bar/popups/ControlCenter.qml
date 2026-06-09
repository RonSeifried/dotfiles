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

    visible: popupVisible
    color: "transparent"
    implicitWidth: 360
    implicitHeight: panelOuter.implicitHeight

    BackgroundEffect.blurRegion: Region {
        x: panelOuter.x; y: panelOuter.y
        width: panelOuter.width; height: panelOuter.implicitHeight
        bottomLeftRadius: Theme.radiusLarge; bottomRightRadius: Theme.radiusLarge
    }

    anchor.window: bar
    anchor.rect.x: anchorItem ? anchorItem.x + anchorItem.width - 360 : 0
    anchor.rect.y: bar ? bar.implicitHeight - 4 : 0
    anchor.rect.width: 360
    anchor.rect.height: 0

    Connections {
        target: ControlState
        function onControlCenterOpenChanged() {
            if (ControlState.controlCenterOpen && root._onActiveScreen) {
                root.popupVisible = true
                panelOuter.y = -panelOuter.implicitHeight
                slideDown.start()
            } else if (root.popupVisible) {
                slideUp.start()
            }
        }
    }

    NumberAnimation { id: slideDown; target: panelOuter; property: "y"; to: 0
        duration: Theme.durSlide; easing.type: Easing.OutCubic }
    SequentialAnimation {
        id: slideUp
        NumberAnimation { target: panelOuter; property: "y"
            to: -panelOuter.implicitHeight; duration: Theme.durNormal; easing.type: Easing.InCubic }
        ScriptAction { script: root.popupVisible = false }
    }

    Rectangle {
        id: panelOuter
        y: 0
        width: 360
        implicitHeight: body.implicitHeight + 2 * Theme.panelPadding
        topLeftRadius: 0; topRightRadius: 0
        bottomLeftRadius: Theme.radiusLarge; bottomRightRadius: Theme.radiusLarge
        color: "transparent"
        clip: true

        GlassSurface {
            anchors.fill: parent
            level: "e2"; radius: Theme.radiusLarge
            topLeftRadius: 0; topRightRadius: 0
            edges: ["left", "right", "bottom"]
        }

        MouseArea { anchors.fill: parent }
        Item {
            focus: root.popupVisible
            Keys.onEscapePressed: ControlState.closeControlCenter()
        }

        Column {
            id: body
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.panelPadding }
            spacing: Theme.spacingLarge

            Grid {
                width: parent.width
                columns: 2
                columnSpacing: Theme.spacingNormal
                rowSpacing: Theme.spacingNormal
                readonly property real cellW: (width - Theme.spacingNormal) / 2

                GlassTile {
                    width: parent.cellW
                    icon: Networking.wifiEnabled ? "󰖩" : "󰖪"
                    label: "Wi-Fi"
                    sub: Networking.wifiEnabled ? (NetUtils.activeWifi ? NetUtils.activeWifi.name : "On") : "Off"
                    on: Networking.wifiEnabled
                    onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
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
    }
}
