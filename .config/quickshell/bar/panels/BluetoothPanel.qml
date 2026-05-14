import QtQuick
import "../.."
import Quickshell.Bluetooth

Column {
    id: root
    spacing: Theme.spacingSmall
    anchors { left: parent?.left; right: parent?.right }

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

    // Header + toggle
    Row {
        width: parent.width; spacing: Theme.spacingSmall
        Text {
            text: {
                if (!root.adapter) return "󰂲  No adapter"
                const st = root.adapter.state
                if (st === BluetoothAdapterState.Enabled) return "󰂯  Bluetooth"
                if (st === BluetoothAdapterState.Enabling) return "󰂯  Enabling…"
                if (st === BluetoothAdapterState.Disabling) return "󰂲  Disabling…"
                return "󰂲  Bluetooth off"
            }
            color: Colors.text; font.pixelSize: Theme.fontNormal; font.bold: true
            font.family: Theme.fontFamily
            width: parent.width - btToggle.width - 6
        }
        Rectangle {
            id: btToggle
            width: 36; height: 20; radius: 10
            property bool on: root.adapter?.enabled ?? false
            color: on ? Qt.rgba(Colors.success.r, Colors.success.g, Colors.success.b, 0.5) : Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, 0.5)
            border.color: on ? Colors.success : Colors.textMuted; border.width: 1
            Rectangle {
                width: 14; height: 14; radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: btToggle.on ? parent.width - width - 3 : 3
                color: btToggle.on ? Colors.success : Colors.textMuted
                Behavior on x { NumberAnimation { duration: 150 } }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: { if (root.adapter) root.adapter.enabled = !root.adapter.enabled }
            }
        }
    }

    // Scan button
    Rectangle {
        id: scanBtn
        visible: root.adapter?.enabled ?? false
        width: parent.width; height: 28; radius: Theme.radiusTiny
        property bool scanning: root.adapter?.discovering ?? false
        color: scanning
            ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.25)
            : Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, 0.4)
        border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.3); border.width: 1
        Row { anchors.centerIn: parent; spacing: Theme.spacingSmall
            Text { text: scanBtn.scanning ? "󰍷" : "󰂍"; color: Colors.text; font.pixelSize: Theme.fontMedium; font.family: Theme.fontFamily }
            Text { text: scanBtn.scanning ? "Scanning…" : "Scan for devices"; color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: { if (root.adapter) root.adapter.discovering = !root.adapter.discovering }
        }
    }

    // ── Paired devices ───────────────────────────────────────────
    Rectangle {
        visible: (root.adapter?.enabled ?? false) && root.pairedDevices.length > 0
        width: parent.width; height: 1
        color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.dividerAlpha)
    }

    Text {
        visible: (root.adapter?.enabled ?? false) && root.pairedDevices.length > 0
        text: "Paired"
        color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.bold: true
        font.family: Theme.fontFamily
    }

    Repeater {
        model: root.pairedDevices
        delegate: Rectangle {
            id: pairedItem
            required property var modelData
            width: parent.width; height: 34; radius: Theme.radiusTiny
            property bool isConnected: modelData.connected
            color: isConnected
                ? Qt.rgba(Colors.success.r, Colors.success.g, Colors.success.b, 0.15)
                : pHov.containsMouse ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.1) : "transparent"
            border.color: isConnected ? Qt.rgba(Colors.success.r, Colors.success.g, Colors.success.b, 0.3) : "transparent"; border.width: 1

            Row {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 8; rightMargin: 8 }
                spacing: Theme.spacingNormal
                Text {
                    text: root._iconFor(pairedItem.modelData)
                    color: pairedItem.isConnected ? Colors.success : Colors.textMuted
                    font.pixelSize: 14; font.family: Theme.fontFamily
                }
                Column {
                    spacing: 1; width: parent.width - 92
                    Text { text: pairedItem.modelData.name; color: Colors.text; font.pixelSize: Theme.fontNormal; font.family: Theme.fontFamily; width: parent.width; elide: Text.ElideRight }
                    Text {
                        text: root._statusText(pairedItem.modelData)
                        color: pairedItem.isConnected ? Colors.success : Colors.textMuted
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
                    text: "✕"
                    color: forgetHov.containsMouse ? Colors.error : Colors.textMuted
                    font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily
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
        visible: (root.adapter?.enabled ?? false) && root.pairedDevices.length === 0 && root.discoveredDevices.length === 0
        width: parent.width; text: "No devices"
        color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily
        horizontalAlignment: Text.AlignHCenter
    }

    // ── Discovered devices ───────────────────────────────────────
    Rectangle {
        visible: (root.adapter?.enabled ?? false) && root.discoveredDevices.length > 0
        width: parent.width; height: 1
        color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.dividerAlpha)
    }

    Text {
        visible: (root.adapter?.enabled ?? false) && root.discoveredDevices.length > 0
        text: "Available"
        color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.bold: true
        font.family: Theme.fontFamily
    }

    Repeater {
        model: root.discoveredDevices
        delegate: Rectangle {
            id: discItem
            required property var modelData
            width: parent.width; height: 34; radius: Theme.radiusTiny
            color: dHov.containsMouse ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.1) : "transparent"

            Row {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 8; rightMargin: 8 }
                spacing: Theme.spacingNormal
                Text {
                    text: root._iconFor(discItem.modelData)
                    color: Colors.textMuted
                    font.pixelSize: 14; font.family: Theme.fontFamily
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
