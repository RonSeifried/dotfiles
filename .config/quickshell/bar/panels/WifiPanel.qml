import QtQuick
import "../.."

Column {
    id: root
    spacing: Theme.spacingSmall
    anchors { left: parent?.left; right: parent?.right }

    property string connectingTo: ""
    property bool needsPassword: false

    Component.onCompleted: { NetworkState.refreshNetworks(); NetworkState.refreshVpns() }

    // Header row
    Row {
        width: parent.width; spacing: Theme.spacingSmall
        Text {
            text: NetworkState.connType === "wifi" ? NetworkState.signalIcon(NetworkState.signal) + "  " + NetworkState.ssid
                : NetworkState.connType === "ethernet" ? "󰈀  Ethernet"
                : NetworkState.wifiEnabled ? "󰤭  Not connected" : "󰤯  Wi-Fi off"
            color: Colors.text; font.pixelSize: Theme.fontNormal; font.bold: true
            font.family: Theme.fontFamily
            width: parent.width - toggleBtn.width - 6; elide: Text.ElideRight
        }
        Rectangle {
            id: toggleBtn
            width: 36; height: 20; radius: 10
            color: NetworkState.wifiEnabled
                ? Qt.rgba(Colors.success.r, Colors.success.g, Colors.success.b, 0.5)
                : Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, 0.5)
            border.color: NetworkState.wifiEnabled ? Colors.success : Colors.textMuted
            border.width: 1
            Rectangle {
                width: 14; height: 14; radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: NetworkState.wifiEnabled ? parent.width - width - 3 : 3
                color: NetworkState.wifiEnabled ? Colors.success : Colors.textMuted
                Behavior on x { NumberAnimation { duration: 150 } }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: NetworkState.toggleWifi() }
        }
    }

    // Disconnect + rescan when connected
    Row {
        visible: NetworkState.connType !== "none"
        width: parent.width; spacing: Theme.spacingSmall
        Rectangle {
            width: (parent.width - 6) / 2; height: 26; radius: Theme.radiusTiny
            color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, 0.5)
            border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.3); border.width: 1
            Text { anchors.centerIn: parent; text: "Disconnect"; color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: NetworkState.disconnect() }
        }
        Rectangle {
            width: (parent.width - 6) / 2; height: 26; radius: Theme.radiusTiny
            color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, 0.5)
            border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.3); border.width: 1
            Text { anchors.centerIn: parent; text: "󰑓  Rescan"; color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { NetworkState.rescan(); NetworkState.refreshNetworks() } }
        }
    }

    // Password input (when needed)
    Rectangle {
        visible: root.needsPassword
        width: parent.width; height: 32; radius: Theme.radiusTiny
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.6)
        border.color: Colors.accent; border.width: 1
        Row {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 8 }
            spacing: Theme.spacingSmall
            Text { text: "󰌆"; color: Colors.textMuted; font.pixelSize: Theme.fontMedium; font.family: Theme.fontFamily; anchors.verticalCenter: parent.verticalCenter }
            Item {
                width: parent.width - 40; height: pwInput.height
                Text { anchors.fill: parent; text: "Password..."; color: Colors.textMuted; font.pixelSize: Theme.fontNormal; font.family: Theme.fontFamily; visible: pwInput.text.length === 0; verticalAlignment: Text.AlignVCenter }
                TextInput {
                    id: pwInput
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                    color: Colors.text; font.pixelSize: Theme.fontNormal; font.family: Theme.fontFamily
                    echoMode: TextInput.Password
                    onAccepted: {
                        root.needsPassword = false
                        NetworkState.connectTo(root.connectingTo, text)
                        text = ""
                    }
                    Component.onCompleted: forceActiveFocus()
                }
            }
        }
    }

    // Divider
    Rectangle { visible: NetworkState.wifiEnabled; width: parent.width; height: 1; color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.dividerAlpha) }

    // Network list
    Column {
        visible: NetworkState.wifiEnabled
        width: parent.width; spacing: 2

        Repeater {
            model: NetworkState.networks.slice(0, 8)
            delegate: Rectangle {
                id: netItem
                required property var modelData
                width: parent.width; height: 30; radius: Theme.radiusTiny
                color: modelData.active
                    ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.25)
                    : hov.containsMouse ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.12) : "transparent"

                Row {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 8; rightMargin: 8 }
                    spacing: Theme.spacingSmall
                    Text { text: NetworkState.signalIcon(netItem.modelData.signal); color: netItem.modelData.active ? Colors.success : Colors.textMuted; font.pixelSize: Theme.fontMedium; font.family: Theme.fontFamily }
                    Text { text: netItem.modelData.ssid; color: Colors.text; font.pixelSize: Theme.fontNormal; font.family: Theme.fontFamily; width: parent.width - 50; elide: Text.ElideRight }
                    Text { visible: netItem.modelData.security !== ""; text: "󰌆"; color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily }
                }
                MouseArea {
                    id: hov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (netItem.modelData.active) return
                        // First click on a different SSID: try saved/open connect.
                        // Second click on same SSID: prompt for password.
                        if (root.connectingTo === netItem.modelData.ssid && netItem.modelData.security !== "") {
                            root.needsPassword = true
                        } else {
                            root.connectingTo = netItem.modelData.ssid
                            root.needsPassword = false
                            NetworkState.connectTo(netItem.modelData.ssid, "")
                        }
                    }
                }
            }
        }

        Text {
            visible: NetworkState.networks.length === 0
            width: parent.width; text: "No networks found"
            color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // ── VPN section ──────────────────────────────────────────────
    Rectangle {
        visible: NetworkState.vpns.length > 0
        width: parent.width; height: 1
        color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.dividerAlpha)
    }

    Text {
        visible: NetworkState.vpns.length > 0
        text: "󰒃  VPN"
        color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.bold: true
        font.family: Theme.fontFamily
    }

    Column {
        visible: NetworkState.vpns.length > 0
        width: parent.width; spacing: 2

        Repeater {
            model: NetworkState.vpns
            delegate: Rectangle {
                id: vpnItem
                required property var modelData
                width: parent.width; height: 30; radius: Theme.radiusTiny
                color: modelData.active
                    ? Qt.rgba(Colors.success.r, Colors.success.g, Colors.success.b, 0.18)
                    : vpnHov.containsMouse ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.12) : "transparent"
                border.color: modelData.active ? Qt.rgba(Colors.success.r, Colors.success.g, Colors.success.b, 0.4) : "transparent"
                border.width: 1

                Row {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 8; rightMargin: 8 }
                    spacing: Theme.spacingSmall
                    Text {
                        text: vpnItem.modelData.active ? "󰌾" : "󰌿"
                        color: vpnItem.modelData.active ? Colors.success : Colors.textMuted
                        font.pixelSize: Theme.fontMedium; font.family: Theme.fontFamily
                    }
                    Text {
                        text: vpnItem.modelData.name
                        color: Colors.text
                        font.pixelSize: Theme.fontNormal; font.family: Theme.fontFamily
                        width: parent.width - 60; elide: Text.ElideRight
                    }
                    Text {
                        text: vpnItem.modelData.type === "wireguard" ? "WG" : "OVPN"
                        color: Colors.textMuted
                        font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily
                    }
                }
                MouseArea {
                    id: vpnHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: NetworkState.toggleVpn(vpnItem.modelData.name, !vpnItem.modelData.active)
                }
            }
        }
    }
}
