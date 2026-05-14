import QtQuick
import QtQuick.Controls
import Quickshell.Networking
import "../.."

Column {
    id: root
    spacing: Theme.spacingSmall
    anchors { left: parent?.left; right: parent?.right }

    // ── State machine ────────────────────────────────────────────
    // "idle"          — no in-flight action
    // "needsPassword" — secured + unknown: show input
    // "connecting"    — connect() / connectWithPsk() called
    // "error"         — connectionFailed signal fired
    property string flowState: "idle"
    property var pendingNet: null
    property string lastError: ""

    function _clearFlow() {
        root.flowState = "idle"
        root.pendingNet = null
        root.lastError = ""
        pwInput.text = ""
    }

    // Scanner runs only while panel is visible.
    Connections {
        target: NetUtils
        function onWifiDeviceChanged() { root._applyScanner() }
    }
    function _applyScanner() {
        if (NetUtils.wifiDevice) NetUtils.wifiDevice.scannerEnabled = visible
    }
    onVisibleChanged: { _applyScanner(); if (!visible) _clearFlow() }
    Component.onCompleted: { _applyScanner(); VpnState.refresh() }
    Component.onDestruction: { if (NetUtils.wifiDevice) NetUtils.wifiDevice.scannerEnabled = false }

    // Force rescan via toggle + delayed re-enable so NM actually triggers a fresh scan.
    Timer { id: rescanTimer; interval: 200; repeat: false
        onTriggered: { if (NetUtils.wifiDevice) NetUtils.wifiDevice.scannerEnabled = true }
    }
    function rescan() {
        const d = NetUtils.wifiDevice
        if (!d) return
        d.scannerEnabled = false
        rescanTimer.restart()
    }

    // Deduplicated/sorted list of WifiNetwork objects.
    readonly property var wifiNets: {
        const d = NetUtils.wifiDevice
        if (!d || !d.networks) return []
        const seen = {}
        for (let i = 0; i < d.networks.values.length; ++i) {
            const n = d.networks.values[i]
            if (!n || !n.name) continue
            if (!seen[n.name] || n.signalStrength > seen[n.name].signalStrength) seen[n.name] = n
        }
        return Object.values(seen).sort((a, b) => b.signalStrength - a.signalStrength)
    }

    function _headerText() {
        if (root.flowState === "connecting" && root.pendingNet) return "󰤨  Connecting to " + root.pendingNet.name + "…"
        if (NetUtils.activeWifi) return NetUtils.signalIcon(NetUtils.activeWifi.signalStrength) + "  " + NetUtils.activeWifi.name
        if (NetUtils.wiredConnected) return "󰈀  Ethernet"
        if (Networking.wifiEnabled) return "󰤭  Not connected"
        return "󰤯  Wi-Fi off"
    }

    // Listen for connection failures on the pending net.
    Connections {
        target: root.pendingNet
        function onConnectionFailed(reason) {
            root.lastError = ConnectionFailReason.toString(reason)
            root.flowState = (reason === ConnectionFailReason.NoSecrets && root.pendingNet?.security !== WifiSecurityType.Open)
                ? "needsPassword" : "error"
        }
        function onConnectedChanged() {
            if (root.pendingNet && root.pendingNet.connected) root._clearFlow()
        }
    }

    // Header row
    Row {
        width: parent.width; spacing: Theme.spacingSmall
        Text {
            text: root._headerText()
            color: Colors.text; font.pixelSize: Theme.fontNormal; font.bold: true
            font.family: Theme.fontFamily
            width: parent.width - toggleBtn.width - 6; elide: Text.ElideRight
        }
        Rectangle {
            id: toggleBtn
            width: 36; height: 20; radius: 10
            color: Networking.wifiEnabled
                ? Qt.rgba(Colors.success.r, Colors.success.g, Colors.success.b, 0.5)
                : Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, 0.5)
            border.color: Networking.wifiEnabled ? Colors.success : Colors.textMuted
            border.width: 1
            Rectangle {
                width: 14; height: 14; radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: Networking.wifiEnabled ? parent.width - width - 3 : 3
                color: Networking.wifiEnabled ? Colors.success : Colors.textMuted
                Behavior on x { NumberAnimation { duration: 150 } }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Networking.wifiEnabled = !Networking.wifiEnabled }
        }
    }

    // Disconnect + rescan when connected
    Row {
        visible: NetUtils.activeWifi || NetUtils.wiredConnected
        width: parent.width; spacing: Theme.spacingSmall
        Rectangle {
            width: (parent.width - 6) / 2; height: 26; radius: Theme.radiusTiny
            color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, 0.5)
            border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.3); border.width: 1
            Text { anchors.centerIn: parent; text: "Disconnect"; color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (NetUtils.activeWifi) NetUtils.activeWifi.disconnect()
                    else if (NetUtils.wiredDevice && NetUtils.wiredDevice.connected) NetUtils.wiredDevice.disconnect()
                    root._clearFlow()
                }
            }
        }
        Rectangle {
            width: (parent.width - 6) / 2; height: 26; radius: Theme.radiusTiny
            color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, 0.5)
            border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.3); border.width: 1
            Text { anchors.centerIn: parent; text: "󰑓  Rescan"; color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.rescan() }
        }
    }

    // Password input (when needed)
    Rectangle {
        id: pwBox
        visible: root.flowState === "needsPassword"
        width: parent.width; height: 32; radius: Theme.radiusTiny
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.6)
        border.color: Colors.accent; border.width: 1
        Row {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 8 }
            spacing: Theme.spacingSmall
            Text { text: "󰌆"; color: Colors.textMuted; font.pixelSize: Theme.fontMedium; font.family: Theme.fontFamily; anchors.verticalCenter: parent.verticalCenter }
            Item {
                width: parent.width - 56; height: pwInput.height
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.fill: parent
                    text: root.pendingNet ? "Password for " + root.pendingNet.name : "Password"
                    color: Colors.textMuted; font.pixelSize: Theme.fontNormal; font.family: Theme.fontFamily
                    visible: pwInput.text.length === 0; verticalAlignment: Text.AlignVCenter
                }
                TextInput {
                    id: pwInput
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                    color: Colors.text; font.pixelSize: Theme.fontNormal; font.family: Theme.fontFamily
                    echoMode: TextInput.Password
                    onAccepted: {
                        if (!root.pendingNet || text.length === 0) return
                        root.flowState = "connecting"
                        root.lastError = ""
                        root.pendingNet.connectWithPsk(text)
                        text = ""
                    }
                    onVisibleChanged: if (visible) forceActiveFocus()
                    Component.onCompleted: forceActiveFocus()
                    Keys.onEscapePressed: root._clearFlow()
                }
            }
            Text {
                text: "✕"; color: Colors.textMuted; font.pixelSize: Theme.fontMedium
                font.family: Theme.fontFamily; anchors.verticalCenter: parent.verticalCenter
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root._clearFlow() }
            }
        }
    }

    // Error / status line
    Text {
        visible: root.flowState === "error" && root.lastError.length > 0
        width: parent.width
        text: "Connection failed: " + root.lastError
        color: Colors.error; font.pixelSize: Theme.fontTiny
        font.family: Theme.fontFamily; wrapMode: Text.WordWrap
    }

    // Divider
    Rectangle { visible: Networking.wifiEnabled; width: parent.width; height: 1; color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.dividerAlpha) }

    // Network list (scrollable, no cap)
    Item {
        width: parent.width
        visible: Networking.wifiEnabled
        // Cap height so panel doesn't grow unbounded; scroll for the rest.
        height: Math.min(netList.contentHeight, 8 * 32)

        ListView {
            id: netList
            anchors.fill: parent
            model: root.wifiNets
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Rectangle {
                id: netItem
                required property var modelData
                readonly property bool isActive: modelData && modelData.connected
                readonly property bool isPending: root.pendingNet === modelData
                readonly property bool isSecure: modelData && modelData.security !== WifiSecurityType.Open
                width: netList.width; height: 30; radius: Theme.radiusTiny
                color: isActive
                    ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.25)
                    : isPending
                        ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.18)
                        : hov.containsMouse
                            ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.12)
                            : "transparent"

                Row {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 8; rightMargin: 8 }
                    spacing: Theme.spacingSmall
                    Text { text: NetUtils.signalIcon(netItem.modelData.signalStrength); color: netItem.isActive ? Colors.success : Colors.textMuted; font.pixelSize: Theme.fontMedium; font.family: Theme.fontFamily }
                    Text { text: netItem.modelData.name; color: Colors.text; font.pixelSize: Theme.fontNormal; font.family: Theme.fontFamily; width: parent.width - 80; elide: Text.ElideRight }
                    Text { visible: netItem.isSecure; text: "󰌆"; color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily }
                    Text {
                        visible: netItem.modelData.known
                        text: "★"
                        color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily
                    }
                }
                MouseArea {
                    id: hov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: ev => {
                        if (ev.button === Qt.RightButton) {
                            // Right-click on known network → forget
                            if (netItem.modelData.known) netItem.modelData.forget()
                            return
                        }
                        if (netItem.isActive) return
                        root.lastError = ""
                        root.pendingNet = netItem.modelData
                        if (netItem.isSecure && !netItem.modelData.known) {
                            root.flowState = "needsPassword"
                        } else {
                            root.flowState = "connecting"
                            netItem.modelData.connect()
                        }
                    }
                }
            }
        }
    }

    Text {
        visible: Networking.wifiEnabled && root.wifiNets.length === 0
        width: parent.width; text: "No networks found"
        color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily
        horizontalAlignment: Text.AlignHCenter
    }

    // ── VPN section ──────────────────────────────────────────────
    Rectangle {
        visible: VpnState.vpns.length > 0
        width: parent.width; height: 1
        color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.dividerAlpha)
    }

    Text {
        visible: VpnState.vpns.length > 0
        text: "󰒃  VPN"
        color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.bold: true
        font.family: Theme.fontFamily
    }

    Column {
        visible: VpnState.vpns.length > 0
        width: parent.width; spacing: 2

        Repeater {
            model: VpnState.vpns
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
                    onClicked: VpnState.toggleVpn(vpnItem.modelData.name, !vpnItem.modelData.active)
                }
            }
        }
    }
}
