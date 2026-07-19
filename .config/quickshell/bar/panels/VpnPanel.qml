import QtQuick
import "../.."

// Standalone VPN detail (was buried in WifiPanel). Lists wireguard/openvpn
// connections from VpnState with per-row activate/deactivate toggles.
Column {
    id: root
    spacing: Theme.spacingSmall
    anchors { left: parent?.left; right: parent?.right }

    Component.onCompleted: VpnState.refresh()

    Text {
        visible: VpnState.vpns.length === 0
        width: parent.width
        text: "No VPN connections configured"
        color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily
        horizontalAlignment: Text.AlignHCenter
    }

    Repeater {
        model: VpnState.vpns
        delegate: Rectangle {
            id: vpnItem
            required property var modelData
            // List row: accent fill = active (state), white hover, no border.
            width: parent.width; height: 38; radius: Theme.radiusSmall
            color: modelData.active
                ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.22)
                : vpnHov.containsMouse ? Qt.rgba(1, 1, 1, Theme.hoverBrightness) : "transparent"

            Row {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 8; rightMargin: 8 }
                spacing: Theme.spacingSmall
                Text {
                    text: vpnItem.modelData.active ? "󰌾" : "󰌿"
                    color: vpnItem.modelData.active ? Colors.accent : Colors.textMuted
                    font.pixelSize: Theme.fontMedium; font.family: Theme.fontIcon
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: vpnItem.modelData.name
                    color: Colors.text
                    font.pixelSize: Theme.fontNormal; font.family: Theme.fontFamily
                    width: parent.width - 64; elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: vpnItem.modelData.type === "wireguard" ? "WG" : "OVPN"
                    color: Colors.textMuted
                    font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MouseArea {
                id: vpnHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: VpnState.toggleVpn(vpnItem.modelData.name, !vpnItem.modelData.active)
            }
        }
    }
}
