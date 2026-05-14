import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import "../../.."
import ".."

Item {
    id: view

    Process {
        id: gatewayLaunch
        // Spawn docker mcp gateway in detached kitty terminal (long-running).
        // Title + class match niri window-rule for floating placement.
        command: [
            "kitty", "--detach", "--class", "mcp-gateway",
            "-T", "MCP Gateway",
            "-o", "font_size=13",
            "-e", "docker", "mcp", "gateway", "run"
        ]
    }

    Process {
        id: rebuildConfig
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: if (text.length > 0) console.warn("[gateway config]", text.trim())
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingLarge

        Text {
            text: "Gateway"
            color: Colors.text
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontLarge
            font.bold: true
        }
        Text {
            Layout.fillWidth: true
            text: "Run the MCP gateway in a floating kitty terminal. Reads secrets.env so clients receive env vars when invoking servers."
            color: Colors.textMuted
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSmall
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingNormal

            // Start gateway
            Rectangle {
                Layout.preferredHeight: 36
                Layout.preferredWidth: 160
                radius: Theme.radiusMedium
                color: startHover.containsMouse
                    ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 1.0)
                    : Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.85)
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: "󰒋"
                        color: Colors.bg
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                    }
                    Text {
                        text: "Start Gateway"
                        color: Colors.bg
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontNormal
                        font.bold: true
                    }
                }
                MouseArea {
                    id: startHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: gatewayLaunch.running = true
                }
            }

            // Ensure gateway config
            Rectangle {
                Layout.preferredHeight: 36
                Layout.preferredWidth: 200
                radius: Theme.radiusMedium
                color: ensureHover.containsMouse
                    ? Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.10)
                    : "transparent"
                border.color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.25)
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "Patch ~/.claude.json"
                    color: Colors.text
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontNormal
                }
                MouseArea {
                    id: ensureHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: McpState.ensureGatewayConfig()
                }
            }

            Item { Layout.fillWidth: true }
        }

        // Stats card
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: statsCol.implicitHeight + 24
            radius: Theme.radiusMedium
            color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, 0.5)
            border.color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.10)
            border.width: 1

            ColumnLayout {
                id: statsCol
                anchors {
                    left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                    leftMargin: 16; rightMargin: 16
                }
                spacing: Theme.spacingSmall

                Text {
                    text: "Overview"
                    color: Colors.text
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontMedium
                    font.bold: true
                }
                StatRow { label: "Catalog entries"; value: McpState.catalog.length }
                StatRow { label: "Enabled servers"; value: McpState.servers.length }
                StatRow { label: "Available tools"; value: McpState.tools.length }
                StatRow { label: "Connected clients"; value: McpState.clients.filter(c => c.connected).length }
                StatRow { label: "Stored secrets";  value: Object.keys(McpState.secrets).length }
            }
        }

        Item { Layout.fillHeight: true }
    }

    component StatRow: RowLayout {
        property string label: ""
        property int value: 0
        Layout.fillWidth: true
        spacing: Theme.spacingNormal
        Text {
            Layout.fillWidth: true
            text: parent.label
            color: Colors.textMuted
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSmall
        }
        Text {
            text: parent.value
            color: Colors.text
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSmall
            font.bold: true
        }
    }
}
