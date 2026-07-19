import QtQuick
import QtQuick.Controls
import "../.."
import "../../components"
import "../panels"
import Quickshell
import Quickshell.Wayland
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower

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
    readonly property int panelWidth: Math.round(Math.min(380, Math.max(320,
        bar && bar.screen ? bar.screen.width * 0.28 : 360)))

    component CompactToggle: GlassSurface {
        id: compact
        property string icon: ""
        property string label: ""
        property bool on: false
        signal toggled()
        height: 58
        level: "e1"
        radius: Theme.radiusMedium
        interactive: true
        accessibleName: label
        Accessible.checkable: true
        Accessible.checked: on
        onClicked: toggled()
        Column {
            anchors.centerIn: parent; spacing: Theme.spacingTight
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: compact.icon
                color: compact.on ? Colors.accent : Colors.textMuted
                font.pixelSize: Theme.fontLarge; font.family: Theme.fontIcon
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: compact.label; color: Colors.text
                font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily
            }
        }
    }

    visible: popupVisible
    color: "transparent"
    implicitWidth: panelWidth
    // Window includes the gap strip above the glass so its hover area reaches up
    // to the bar — no dead zone between the CC button and the floating panel.
    readonly property int ccGap: Theme.barMargin
    implicitHeight: ccGap + panelOuter.implicitHeight
        + (notifOuter.visible ? ccGap + notifOuter.implicitHeight : 0)

    // Hover the whole window (gap strip + panel); the bar guards on panelHovered.
    HoverHandler { id: ccHover }

    BackgroundEffect.blurRegion: Region {
        x: panelOuter.x; y: panelOuter.y
        width: panelOuter.width; height: panelOuter.implicitHeight
        topLeftRadius: Theme.radiusXL; topRightRadius: Theme.radiusXL
        bottomLeftRadius: Theme.radiusXL; bottomRightRadius: Theme.radiusXL
        // Second lobe: the notification panel below the CC shares the blur.
        regions: [
            Region {
                x: notifOuter.x; y: notifOuter.y
                width: notifOuter.visible ? notifOuter.width : 0
                height: notifOuter.visible ? notifOuter.implicitHeight : 0
                topLeftRadius: Theme.radiusXL; topRightRadius: Theme.radiusXL
                bottomLeftRadius: Theme.radiusXL; bottomRightRadius: Theme.radiusXL
            }
        ]
    }

    // Floating panel: right-aligned to the cluster. Window touches the bar; the
    // visual gap is the transparent strip above the glass inside the window.
    anchor.window: bar
    // Right edge flush with the bar's right edge (the glass end), so the panel,
    // toasts and menus all line up vertically — not offset by the cluster inset.
    anchor.rect.x: bar ? bar.width - root.panelWidth : 0
    anchor.rect.y: bar ? bar.implicitHeight : 0
    anchor.rect.width: root.panelWidth
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
        width: root.panelWidth
        implicitHeight: body.height + 2 * Theme.panelPadding
        radius: Theme.radiusXL
        color: "transparent"
        clip: true

        // Floating glass: fully rounded, full border (all four corners traced).
        GlassSurface {
            anchors.fill: parent
            level: "e3"; radius: Theme.radiusXL
        }

        MouseArea { anchors.fill: parent }
        Item {
            focus: root.popupVisible
            Keys.onEscapePressed: ControlState.closeControlCenter()
        }

        Flickable {
            id: body
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.panelPadding }
            readonly property bool detail: ControlState.ccSection !== ""
            readonly property real contentH: detail ? detailLayer.implicitHeight : mainLayer.implicitHeight
            // Cap to the screen so a tall stack (calendar + history) scrolls
            // instead of running off the bottom edge.
            readonly property real maxBodyHeight: (root.bar && root.bar.screen ? root.bar.screen.height : 1000)
                - (root.bar ? root.bar.implicitHeight : 36) - 2 * Theme.panelPadding
                - (notifOuter.visible ? Math.min(notifOuter.implicitHeight + root.ccGap, 150) : 0) - 32
            height: Math.min(contentH, maxBodyHeight)
            contentHeight: contentH
            contentWidth: width
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentH > height
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            Behavior on height { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }

            Column {
                id: mainLayer
                width: parent.width
                spacing: Theme.spacingNormal
                opacity: body.detail ? 0 : 1
                x: body.detail ? -8 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
                Behavior on x { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }

                // ── Date / time (compact, expands to a month grid) ──
                Column {
                    id: calSection
                    width: parent.width
                    spacing: Theme.spacingSmall
                    SystemClock { id: ccClock; precision: SystemClock.Minutes }

                    Item {
                        width: parent.width
                        height: 38
                        Column {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            spacing: 0
                            Text {
                                text: Qt.formatTime(ccClock.date, "HH:mm")
                                color: Colors.text; font.pixelSize: Theme.fontLarge + 4; font.bold: true
                                font.family: Theme.fontFamily
                            }
                            Text {
                                text: Qt.formatDate(ccClock.date, "dddd, d. MMMM")
                                color: Colors.textMuted; font.pixelSize: Theme.fontSmall
                                font.family: Theme.fontFamily
                            }
                        }
                        Text {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            text: "󰅂"
                            color: Colors.textMuted
                            font.pixelSize: Theme.fontLarge; font.family: Theme.fontIcon
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: ControlState.ccSection = "calendar"
                        }
                    }
                }

                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: Theme.spacingSmall
                    rowSpacing: Theme.spacingSmall
                    readonly property real cellW: (width - Theme.spacingSmall) / 2

                    GlassTile {
                        width: parent.cellW
                        expandable: true
                        icon: Networking.wifiEnabled ? "󰖩" : "󰖪"
                        label: "Wi-Fi"
                        sub: Networking.wifiEnabled ? (NetUtils.activeWifi ? NetUtils.activeWifi.name : "On") : "Off"
                        on: Networking.wifiEnabled
                        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                        onOpened: ControlState.ccSection = "wifi"
                    }
                    GlassTile {
                        width: parent.cellW
                        expandable: true
                        icon: "󰂯"
                        label: "Bluetooth"
                        on: !!(Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled)
                        sub: {
                            if (!Bluetooth.defaultAdapter || !Bluetooth.defaultAdapter.enabled) return "Off"
                            for (const d of Bluetooth.devices.values) if (d.connected) return d.name
                            return "On"
                        }
                        onToggled: if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                        onOpened: ControlState.ccSection = "bluetooth"
                    }
                }

                // Secondary controls stay one quiet tier below connectivity.
                Row {
                    width: parent.width; spacing: Theme.spacingSmall
                    readonly property real cellW: (width - 3 * spacing) / 4
                    CompactToggle {
                        width: parent.cellW; icon: NightLightState.on ? "󰖔" : "󰛨"
                        label: "Night Light"; on: NightLightState.on
                        onToggled: NightLightState.toggle()
                    }
                    CompactToggle {
                        width: parent.cellW; icon: NotifState.dnd ? "󰂛" : "󰂚"
                        label: "Focus"; on: FocusState.activeScene !== "off"
                        onToggled: ControlState.ccSection = "focus"
                    }
                    CompactToggle {
                        width: parent.cellW; icon: "󰅶"; label: "Caffeine"
                        on: ControlState.idleInhibited
                        onToggled: ControlState.idleInhibited = !ControlState.idleInhibited
                    }
                    CompactToggle {
                        width: parent.cellW; icon: VpnState.anyVpnActive ? "󰦝" : "󰒄"
                        label: "VPN"; on: VpnState.anyVpnActive
                        onToggled: ControlState.ccSection = "vpn"
                    }
                }

                Column {
                    id: soundCol
                    width: parent.width
                    spacing: Theme.spacingNormal
                    property bool outputOpen: false
                    // Shared row metrics: icon slot (20 + spacing) and trailing
                    // slot (22px button + spacing) so all slider edges align.
                    readonly property int leadSlot: 20 + Theme.spacingNormal
                    readonly property int trailSlot: 22 + Theme.spacingNormal

                    // Volume — leading mute glyph, chunky slider, trailing output
                    // picker button (macOS AirPlay-style). The raw device name is
                    // hidden behind the button; tapping it reveals the list.
                    Row {
                        width: parent.width; spacing: Theme.spacingNormal
                        readonly property bool hasPicker: AudioState.sinks.length > 1
                        Text {
                            // Fixed slot so the volume + brightness sliders start
                            // at the same x regardless of glyph width.
                            width: 20; horizontalAlignment: Text.AlignHCenter
                            text: AudioState.muted ? "󰖁" : "󰕾"; color: Colors.text
                            font.pixelSize: 16; font.family: Theme.fontIcon
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: AudioState.toggleMute() }
                        }
                        GlassSlider {
                            accessibleName: "Output volume"
                            width: parent.width - soundCol.leadSlot - (parent.hasPicker ? soundCol.trailSlot : 0)
                            anchors.verticalCenter: parent.verticalCenter
                            value: AudioState.volume; max: 1.0; active: !AudioState.muted
                            onMoved: v => AudioState.setVolume(v)
                        }
                        Rectangle {
                            visible: parent.hasPicker
                            width: 22; height: 22; radius: Theme.radiusTiny
                            anchors.verticalCenter: parent.verticalCenter
                            color: soundCol.outputOpen
                                ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.22)
                                : outHov.containsMouse ? Qt.rgba(1, 1, 1, Theme.hoverBrightness) : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "󰓃"
                                color: soundCol.outputOpen ? Colors.accent : Colors.textMuted
                                font.pixelSize: Theme.fontMedium; font.family: Theme.fontIcon
                            }
                            MouseArea {
                                id: outHov; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: soundCol.outputOpen = !soundCol.outputOpen
                            }
                        }
                    }
                    // Output device list — revealed by the picker button.
                    Column {
                        width: parent.width
                        spacing: 2
                        visible: AudioState.sinks.length > 1

                        Column {
                            width: parent.width; spacing: 2
                            visible: soundCol.outputOpen

                            Repeater {
                                model: AudioState.sinks
                                delegate: Rectangle {
                                    id: sinkItem
                                    required property var modelData
                                    readonly property bool isActive: AudioState.sink && modelData.id === AudioState.sink.id
                                    width: parent.width; height: 28; radius: Theme.radiusTiny
                                    color: isActive
                                        ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.22)
                                        : sinkHov.containsMouse ? Qt.rgba(1, 1, 1, Theme.hoverBrightness) : "transparent"
                                    Row {
                                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 8; rightMargin: 8 }
                                        spacing: Theme.spacingSmall
                                        Text {
                                            text: AudioState.sinkLabel(sinkItem.modelData)
                                            color: sinkItem.isActive ? Colors.accent : Colors.text
                                            font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily
                                            width: parent.width - 16; elide: Text.ElideRight
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            visible: sinkItem.isActive
                                            text: "󰄬"; color: Colors.accent
                                            font.pixelSize: Theme.fontSmall; font.family: Theme.fontIcon
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    MouseArea {
                                        id: sinkHov; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { AudioState.setSink(sinkItem.modelData); soundCol.outputOpen = false }
                                    }
                                }
                            }
                        }
                    }

                    // Brightness — Display, like macOS. (Mic level lives in the
                    // sound detail, not the main view — keeps this panel clean.)
                    Row {
                        width: parent.width; spacing: Theme.spacingNormal
                        visible: BrightnessState.available
                        Text {
                            width: 20; horizontalAlignment: Text.AlignHCenter
                            text: "󰃟"; color: Colors.text
                            font.pixelSize: 16; font.family: Theme.fontIcon
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        GlassSlider {
                            accessibleName: "Display brightness"
                            // Match the volume slider's right edge (which reserves
                            // the output-button slot) so both ends line up.
                            width: parent.width - soundCol.leadSlot
                                - (AudioState.sinks.length > 1 ? soundCol.trailSlot : 0)
                            anchors.verticalCenter: parent.verticalCenter
                            value: BrightnessState.value; max: 1.0
                            onMoved: v => BrightnessState.set(v)
                        }
                    }
                }

                // ── Battery row → opens the battery / power detail ───
                GlassTile {
                    id: batteryTile
                    width: parent.width
                    visible: !!dev

                    readonly property var dev: {
                        for (const d of UPower.devices.values)
                            if (d.isLaptopBattery && d.ready && d.percentage > 0.01) return d
                        return null
                    }
                    readonly property int pct: dev ? Math.round(dev.percentage * 100) : 0
                    readonly property bool charging: !!dev && dev.state === 1
                    readonly property string profileName: PowerProfiles.profile === 0 ? "Power Saver"
                        : PowerProfiles.profile === 2 ? "Performance" : "Balanced"

                    expandable: true
                    icon: charging ? "󰂄" : Theme.batteryGlyph(pct)
                    label: "Battery"
                    sub: pct + "%  ·  " + profileName
                    on: charging
                    onToggled: ControlState.ccSection = "battery"
                    onOpened: ControlState.ccSection = "battery"
                }

                MprisPanel {
                    width: parent.width
                    visible: MprisState.hasAny
                }

                GlassSurface {
                    width: parent.width; height: 34
                    level: "e1"; radius: Theme.radiusMedium; interactive: true
                    accessibleName: "Desktop settings"
                    onClicked: ControlState.ccSection = "settings"
                    Row {
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Theme.spacingNormal }
                        spacing: Theme.spacingSmall
                        Text { text: "󰒓"; color: Colors.textMuted; font.pixelSize: Theme.fontMedium; font.family: Theme.fontIcon }
                        Text { width: parent.width - 38; text: "Desktop Settings"; color: Colors.text; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily }
                        Text { text: "󰅂"; color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.family: Theme.fontIcon }
                    }
                }
            }

            Column {
                id: detailLayer
                width: parent.width
                spacing: Theme.spacingNormal
                opacity: body.detail ? 1 : 0
                x: body.detail ? 0 : 8
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
                Behavior on x { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }

                // Header doubles as the back control — the whole row is tappable.
                // The section's master toggle lives HERE (right edge), so no
                // panel repeats its own name in a second header underneath.
                Item {
                    width: parent.width
                    height: backRow.implicitHeight + 4
                    Row {
                        id: backRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingTight
                        Text {
                            text: "󰅁"; color: Colors.accent
                            font.pixelSize: Theme.fontLarge; font.family: Theme.fontIcon
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: ControlState.ccSection === "wifi" ? "Wi-Fi"
                                : ControlState.ccSection === "vpn" ? "VPN"
                                : ControlState.ccSection === "battery" ? "Battery"
                                : ControlState.ccSection === "calendar" ? "Calendar"
                                : ControlState.ccSection === "focus" ? "Focus"
                                : ControlState.ccSection === "settings" ? "Desktop Settings"
                                : "Bluetooth"
                            color: Colors.text; font.pixelSize: Theme.fontMedium; font.bold: true
                            font.family: Theme.fontFamily; anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ControlState.ccSection = "" }

                    GlassToggle {
                        visible: ControlState.ccSection === "wifi" || ControlState.ccSection === "bluetooth"
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        checked: ControlState.ccSection === "wifi"
                            ? Networking.wifiEnabled
                            : !!(Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled)
                        onToggled: v => {
                            if (ControlState.ccSection === "wifi") Networking.wifiEnabled = v
                            else if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = v
                        }
                    }
                }

                Loader {
                    width: parent.width
                    active: body.detail
                    sourceComponent: ControlState.ccSection === "wifi" ? wifiComp
                        : ControlState.ccSection === "bluetooth" ? btComp
                        : ControlState.ccSection === "vpn" ? vpnComp
                        : ControlState.ccSection === "battery" ? batteryComp
                        : ControlState.ccSection === "calendar" ? calendarComp
                        : ControlState.ccSection === "focus" ? focusComp
                        : ControlState.ccSection === "settings" ? settingsComp : null
                }
                Component { id: wifiComp; WifiPanel {} }
                Component { id: btComp; BluetoothPanel {} }
                Component { id: vpnComp; VpnPanel {} }
                Component { id: batteryComp; BatteryPanel {} }
                Component { id: calendarComp; CalendarPanel {} }
                Component { id: focusComp; FocusPanel {} }
                Component { id: settingsComp; SettingsPanel {} }
            }
        }
    }

    // Notification deck below the settings panel (slides + fades with it).
    // Its own floating glass panel — same material as the CC, so both read as
    // one system: two lobes of the same glass.
    Rectangle {
        id: notifOuter
        x: panelOuter.x
        y: panelOuter.y + panelOuter.implicitHeight + root.ccGap
        width: root.panelWidth
        implicitHeight: notifStack.implicitHeight + 2 * Theme.panelPadding
        radius: Theme.radiusXL
        color: "transparent"
        clip: true
        visible: notifStack.count > 0
        opacity: panelOuter.opacity

        GlassSurface {
            anchors.fill: parent
            level: "e3"; radius: Theme.radiusXL
        }
        MouseArea { anchors.fill: parent }

        NotifStack {
            id: notifStack
            x: Theme.panelPadding
            y: Theme.panelPadding
            width: parent.width - 2 * Theme.panelPadding
            maxExpandedHeight: root.bar && root.bar.screen
                ? Math.max(140, Math.min(330, root.bar.screen.height
                    - root.bar.implicitHeight - panelOuter.implicitHeight
                    - 3 * root.ccGap - 2 * Theme.panelPadding))
                : 310
        }
    }
}
