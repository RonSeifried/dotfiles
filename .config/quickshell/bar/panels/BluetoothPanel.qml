import QtQuick
import "../.."
import Quickshell.Bluetooth

Column {
    id: root
    spacing: Theme.spacingSmall
    anchors { left: parent?.left; right: parent?.right }

    property var adapter: Bluetooth.defaultAdapter

    // Header + toggle
    Row {
        width: parent.width; spacing: Theme.spacingSmall
        Text {
            text: {
                if (!root.adapter) return "󰂲  No adapter"
                const st = root.adapter.state
                if (st === BluetoothAdapterState.Enabled) return "󰂯  Bluetooth"
                if (st === BluetoothAdapterState.Enabling) return "󰂯  Enabling..."
                if (st === BluetoothAdapterState.Disabling) return "󰂲  Disabling..."
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
            Text { text: scanBtn.scanning ? "Scanning..." : "Scan for devices"; color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: { if (root.adapter) root.adapter.discovering = !root.adapter.discovering }
        }
    }

    Rectangle {
        visible: (root.adapter?.enabled ?? false) && Bluetooth.devices.values.length > 0
        width: parent.width; height: 1
        color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.dividerAlpha)
    }

    // Device list
    Repeater {
        model: Bluetooth.devices.values
        delegate: Rectangle {
            id: devItem
            required property var modelData
            width: parent.width; height: 34; radius: Theme.radiusTiny
            property bool isConnected: modelData.connected
            color: isConnected
                ? Qt.rgba(Colors.success.r, Colors.success.g, Colors.success.b, 0.15)
                : devHov.containsMouse ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.1) : "transparent"
            border.color: isConnected ? Qt.rgba(Colors.success.r, Colors.success.g, Colors.success.b, 0.3) : "transparent"; border.width: 1

            Row {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 8; rightMargin: 8 }
                spacing: Theme.spacingNormal
                Text {
                    text: {
                        const icon = devItem.modelData.icon
                        if (icon.includes("headset") || icon.includes("headphone")) return "󰋋"
                        if (icon.includes("phone")) return "󰄜"
                        if (icon.includes("keyboard")) return "󰌌"
                        if (icon.includes("mouse")) return "󰍽"
                        if (icon.includes("audio")) return "󰓃"
                        return "󰂱"
                    }
                    color: devItem.isConnected ? Colors.success : Colors.textMuted
                    font.pixelSize: 14; font.family: Theme.fontFamily
                }
                Column {
                    spacing: 1; width: parent.width - 60
                    Text { text: devItem.modelData.name; color: Colors.text; font.pixelSize: Theme.fontNormal; font.family: Theme.fontFamily; width: parent.width; elide: Text.ElideRight }
                    Text {
                        text: {
                            if (devItem.modelData.state === BluetoothDeviceState.Connected) return "Connected"
                            if (devItem.modelData.state === BluetoothDeviceState.Connecting) return "Connecting..."
                            if (devItem.modelData.state === BluetoothDeviceState.Disconnecting) return "Disconnecting..."
                            return devItem.modelData.paired ? "Paired" : "Not paired"
                        }
                        color: devItem.isConnected ? Colors.success : Colors.textMuted
                        font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily
                    }
                }
                Text {
                    visible: devItem.modelData.batteryAvailable
                    text: Math.round(devItem.modelData.battery * 100) + "%"
                    color: Colors.textMuted; font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: devHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (devItem.modelData.connected) devItem.modelData.disconnect()
                    else devItem.modelData.connect()
                }
            }
        }
    }

    Text {
        visible: (root.adapter?.enabled ?? false) && Bluetooth.devices.values.length === 0
        width: parent.width; text: "No paired devices"
        color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily
        horizontalAlignment: Text.AlignHCenter
    }
}
