import QtQuick
import "../.."
import "../../components"
import Quickshell.Bluetooth

Column {
    id: root
    spacing: Theme.spacingSmall
    anchors { left: parent ? parent.left : undefined; right: parent ? parent.right : undefined }

    property var adapter: Bluetooth.defaultAdapter

    // Split paired vs unpaired (discovered) devices.
    readonly property var pairedDevices: {
        const out = []
        for (const d of Bluetooth.devices.values) if (d.paired || d.bonded) out.push(d)
        return out
    }
    readonly property var discoveredDevices: {
        const out = []
        for (const d of Bluetooth.devices.values) if (!d.paired && !d.bonded) out.push(d)
        return out
    }

    function _statusText(d) {
        if (d.state === BluetoothDeviceState.Connected) return "Connected"
        if (d.state === BluetoothDeviceState.Connecting) return "Connecting…"
        if (d.state === BluetoothDeviceState.Disconnecting) return "Disconnecting…"
        if (d.pairing) return "Pairing…"
        return d.paired ? "Paired" : "Not paired"
    }

    function _iconFor(d) {
        const icon = d.icon || ""
        if (icon.includes("headset") || icon.includes("headphone")) return "󰋋"
        if (icon.includes("phone")) return "󰄜"
        if (icon.includes("keyboard")) return "󰌌"
        if (icon.includes("mouse")) return "󰍽"
        if (icon.includes("audio")) return "󰓃"
        return "󰂱"
    }

    // Click handler: pair first if not paired, then connect. If pairing/connecting,
    // tapping again cancels. Connected device → disconnect.
    function _handleClick(d) {
        if (d.connected) { d.disconnect(); return }
        if (d.pairing) { d.cancelPair(); return }
        if (!d.paired && !d.bonded) {
            d.pair()
            return
        }
        d.connect()
    }

    // Auto-connect once pairing finishes (BlueZ doesn't connect automatically
    // for all profiles; only A2DP-likes do).
    Connections {
        target: Bluetooth.devices
        function onValuesChanged() { /* values list rebuilds; rebind happens */ }
    }
    Repeater {
        model: Bluetooth.devices.values
        delegate: Item {
            required property var modelData
            visible: false
            Connections {
                target: modelData
                function onPairedChanged() {
                    if (modelData.paired && !modelData.connected) modelData.connect()
                }
            }
        }
    }

    // Status line — transient adapter states only (the CC header row owns the
    // "Bluetooth" title + master toggle).
    Text {
        visible: {
            if (!root.adapter) return true
            const st = root.adapter.state
            return st === BluetoothAdapterState.Enabling || st === BluetoothAdapterState.Disabling
        }
        width: parent.width
        text: {
            if (!root.adapter) return "󰂲  No Bluetooth adapter"
            return root.adapter.state === BluetoothAdapterState.Enabling ? "Enabling…" : "Disabling…"
        }
        color: Colors.textMuted; font.pixelSize: Theme.fontSmall
        font.family: Theme.fontFamily
    }

    // Scan button — chip vocabulary (0.08 idle, white hover, accent = active).
    GlassSurface {
        id: scanBtn
        visible: root.adapter ? root.adapter.enabled : false
        width: parent.width; height: 32; radius: Theme.radiusSmall
        property bool scanning: root.adapter ? root.adapter.discovering : false
        level: "e1"; frost: true; frostAlpha: scanning ? 0.20 : 0.075
        Row { anchors.centerIn: parent; spacing: Theme.spacingSmall
            Text { text: scanBtn.scanning ? "󰍷" : "󰂍"; color: Colors.text; font.pixelSize: Theme.fontMedium; font.family: Theme.fontIcon }
            Text { text: scanBtn.scanning ? "Scanning…" : "Scan for devices"; color: Colors.text; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily }
        }
        MouseArea { id: scanHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: { if (root.adapter) root.adapter.discovering = !root.adapter.discovering }
        }
    }

    // ── Paired devices ───────────────────────────────────────────
    Rectangle {
        visible: !!root.adapter && root.adapter.enabled && root.pairedDevices.length > 0
        width: parent.width; height: 1
        color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, Colors.dividerAlpha)
    }

    Text {
        visible: !!root.adapter && root.adapter.enabled && root.pairedDevices.length > 0
        text: "Paired"
        color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.bold: true
        font.family: Theme.fontFamily
    }

    Repeater {
        model: root.pairedDevices
        delegate: GlassSurface {
            id: pairedItem
            required property var modelData
            // Connected = accent (state), no border — signal colours stay
            // reserved for real signals.
            width: parent.width; height: 46; radius: Theme.radiusMedium
            property bool isConnected: modelData.connected
            level: "e1"; frost: true; frostAlpha: isConnected ? 0.20 : 0.065

            Row {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 12 }
                spacing: Theme.spacingNormal
                Text {
                    text: root._iconFor(pairedItem.modelData)
                    color: pairedItem.isConnected ? Colors.accent : Colors.textMuted
                    font.pixelSize: 14; font.family: Theme.fontIcon
                }
                Column {
                    spacing: 1; width: parent.width - 92
                    Text { text: pairedItem.modelData.name; color: Colors.text; font.pixelSize: Theme.fontNormal; font.family: Theme.fontFamily; width: parent.width; elide: Text.ElideRight }
                    Text {
                        text: root._statusText(pairedItem.modelData)
                        color: pairedItem.isConnected ? Colors.accent : Colors.textMuted
                        font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily
                    }
                }
                Text {
                    visible: pairedItem.modelData.batteryAvailable
                    text: Math.round(pairedItem.modelData.battery * 100) + "%"
                    color: Colors.textMuted; font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "󰅖"
                    color: forgetHov.containsMouse ? Colors.error : Colors.textMuted
                    font.pixelSize: Theme.fontSmall; font.family: Theme.fontIcon
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea {
                        id: forgetHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: pairedItem.modelData.forget()
                    }
                }
            }

            MouseArea {
                id: pHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root._handleClick(pairedItem.modelData)
                propagateComposedEvents: true
            }
        }
    }

    Text {
        visible: !!root.adapter && root.adapter.enabled && root.pairedDevices.length === 0 && root.discoveredDevices.length === 0
        width: parent.width; text: "No devices"
        color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily
        horizontalAlignment: Text.AlignHCenter
    }

    // ── Discovered devices ───────────────────────────────────────
    Rectangle {
        visible: !!root.adapter && root.adapter.enabled && root.discoveredDevices.length > 0
        width: parent.width; height: 1
        color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, Colors.dividerAlpha)
    }

    Text {
        visible: !!root.adapter && root.adapter.enabled && root.discoveredDevices.length > 0
        text: "Available"
        color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.bold: true
        font.family: Theme.fontFamily
    }

    Repeater {
        model: root.discoveredDevices
        delegate: GlassSurface {
            id: discItem
            required property var modelData
            width: parent.width; height: 46; radius: Theme.radiusMedium
            level: "e1"; frost: true; frostAlpha: 0.065

            Row {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 12 }
                spacing: Theme.spacingNormal
                Text {
                    text: root._iconFor(discItem.modelData)
                    color: Colors.textMuted
                    font.pixelSize: 14; font.family: Theme.fontIcon
                }
                Column {
                    spacing: 1; width: parent.width - 60
                    Text {
                        text: discItem.modelData.name || discItem.modelData.address
                        color: Colors.text; font.pixelSize: Theme.fontNormal
                        font.family: Theme.fontFamily; width: parent.width; elide: Text.ElideRight
                    }
                    Text {
                        text: root._statusText(discItem.modelData)
                        color: Colors.textMuted
                        font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily
                    }
                }
            }

            MouseArea {
                id: dHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root._handleClick(discItem.modelData)
            }
        }
    }
}
