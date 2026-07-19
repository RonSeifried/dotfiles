import QtQuick
import QtQuick.Controls
import Quickshell.Networking
import "../.."
import "../../components"

Column {
    id: root
    spacing: Theme.spacingSmall
    anchors { left: parent ? parent.left : undefined; right: parent ? parent.right : undefined }

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

    // Listen for connection failures on the pending net.
    Connections {
        target: root.pendingNet
        function onConnectionFailed(reason) {
            root.lastError = ConnectionFailReason.toString(reason)
            root.flowState = (reason === ConnectionFailReason.NoSecrets && root.pendingNet && root.pendingNet.security !== WifiSecurityType.Open)
                ? "needsPassword" : "error"
        }
        function onConnectedChanged() {
            if (root.pendingNet && root.pendingNet.connected) root._clearFlow()
        }
    }

    // Status line — transient / non-list states only (the CC header row owns
    // the "Wi-Fi" title + master toggle; the active network is highlighted
    // in the list itself).
    Text {
        visible: root.flowState === "connecting" || NetUtils.wiredConnected
        width: parent.width
        text: root.flowState === "connecting" && root.pendingNet
            ? "󰤨  Connecting to " + root.pendingNet.name + "…"
            : "󰈀  Ethernet connected"
        color: Colors.textMuted; font.pixelSize: Theme.fontSmall
        font.family: Theme.fontFamily; elide: Text.ElideRight
    }

    // Disconnect + rescan when connected. Chip buttons — same vocabulary as
    // the battery panel's profile segments (0.08 idle, white hover).
    Row {
        visible: NetUtils.activeWifi || NetUtils.wiredConnected
        width: parent.width; spacing: Theme.spacingSmall
        Rectangle {
            width: (parent.width - 6) / 2; height: 32; radius: Theme.radiusSmall
            color: dcHov.containsMouse ? Qt.rgba(1, 1, 1, Theme.hoverBrightness) : Qt.rgba(1, 1, 1, 0.08)
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
            Text { anchors.centerIn: parent; text: "Disconnect"; color: Colors.text; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily }
            MouseArea {
                id: dcHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (NetUtils.activeWifi) NetUtils.activeWifi.disconnect()
                    else if (NetUtils.wiredDevice && NetUtils.wiredDevice.connected) NetUtils.wiredDevice.disconnect()
                    root._clearFlow()
                }
            }
        }
        Rectangle {
            width: (parent.width - 6) / 2; height: 32; radius: Theme.radiusSmall
            color: rsHov.containsMouse ? Qt.rgba(1, 1, 1, Theme.hoverBrightness) : Qt.rgba(1, 1, 1, 0.08)
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
            Text { anchors.centerIn: parent; text: "󰑓  Rescan"; color: Colors.text; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily }
            MouseArea { id: rsHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.rescan() }
        }
    }

    // Password input (when needed)
    // Borderless inset well (design language: no nested outline on the glass).
    Rectangle {
        id: pwBox
        visible: root.flowState === "needsPassword"
        width: parent.width; height: 32; radius: Theme.radiusSmall
        color: Qt.rgba(Colors.bg.r, Colors.bg.g, Colors.bg.b, 0.28)
        Row {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 8 }
            spacing: Theme.spacingSmall
            Text { text: "󰌆"; color: Colors.textMuted; font.pixelSize: Theme.fontMedium; font.family: Theme.fontIcon; anchors.verticalCenter: parent.verticalCenter }
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
                text: "󰅖"; color: Colors.textMuted; font.pixelSize: Theme.fontMedium
                font.family: Theme.fontIcon; anchors.verticalCenter: parent.verticalCenter
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
    Rectangle { visible: Networking.wifiEnabled; width: parent.width; height: 1; color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, Colors.dividerAlpha) }

    // Network list (scrollable, no cap)
    Item {
        width: parent.width
        visible: Networking.wifiEnabled
        // Cap height so panel doesn't grow unbounded; scroll for the rest.
        height: Math.min(netList.contentHeight, 8 * 40)

        GlassSurface {
            anchors.fill: parent
            radius: Theme.radiusMedium
            level: "e1"; frost: true; frostAlpha: 0.055
        }

        ListView {
            id: netList
            anchors.fill: parent
            model: root.wifiNets
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: GlassSurface {
                id: netItem
                required property var modelData
                readonly property bool isActive: modelData && modelData.connected
                readonly property bool isPending: root.pendingNet === modelData
                readonly property bool isSecure: modelData && modelData.security !== WifiSecurityType.Open
                width: netList.width; height: 44; radius: Theme.radiusMedium
                level: "e1"; frost: true
                frostAlpha: isActive ? 0.20 : isPending ? 0.16 : 0.055

                Row {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 12 }
                    spacing: Theme.spacingSmall
                    Text { text: NetUtils.signalIcon(netItem.modelData.signalStrength); color: netItem.isActive ? Colors.accent : Colors.textMuted; font.pixelSize: Theme.fontMedium; font.family: Theme.fontIcon }
                    Text { text: netItem.modelData.name; color: Colors.text; font.pixelSize: Theme.fontNormal; font.family: Theme.fontFamily; width: parent.width - 80; elide: Text.ElideRight }
                    Text { visible: netItem.isSecure; text: "󰌆"; color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.family: Theme.fontIcon }
                    Text {
                        visible: netItem.modelData.known
                        text: "󰓎"
                        color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.family: Theme.fontIcon
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
}
