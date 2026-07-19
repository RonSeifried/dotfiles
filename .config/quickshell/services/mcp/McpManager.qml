import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../.."
import "../../components"
import "./views"

// Floating xdg-toplevel window for managing docker mcp.
// niri owns the chrome (border, drag, close button) via window-rule app-id match.
FloatingWindow {
    id: root

    title: "MCP Manager"
    minimumSize: Qt.size(720, 480)
    implicitWidth: 960
    implicitHeight: 640
    color: "transparent"

    property string currentView: "catalog"     // catalog | servers | clients | tools | gateway | detail

    onVisibleChanged: {
        if (visible) {
            McpState.refreshAll()
            currentView = "catalog"
        }
    }

    // ── content frame ────────────────────────────────────────────
    GlassSurface {
        anchors.fill: parent
        level: "e3"; radius: Theme.radiusXL; frost: true; frostAlpha: 0.10

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ── sidebar ──────────────────────────────────────────
            GlassSurface {
                Layout.preferredWidth: 180
                Layout.fillHeight: true
                level: "e1"; radius: 0; frost: true; frostAlpha: 0.075

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLarge
                    spacing: Theme.spacingSmall

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: Theme.spacingNormal
                        spacing: Theme.spacingNormal

                        Text {
                            text: "󰡨"
                            font.family: Theme.fontIcon
                            font.pixelSize: 22
                            color: Colors.accent
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "Docker MCP"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLarge
                            font.bold: true
                            color: Colors.text
                            elide: Text.ElideRight
                        }
                    }

                    SideButton {
                        Layout.fillWidth: true
                        icon: "󰏗"
                        label: "Catalog"
                        active: root.currentView === "catalog"
                        onClicked: root.currentView = "catalog"
                    }
                    SideButton {
                        Layout.fillWidth: true
                        icon: "󱘖"
                        label: "Servers"
                        badge: McpState.servers.length
                        active: root.currentView === "servers" || root.currentView === "detail"
                        onClicked: root.currentView = "servers"
                    }
                    SideButton {
                        Layout.fillWidth: true
                        icon: "󰙯"
                        label: "Clients"
                        badge: McpState.clients.filter(c => c.connected).length
                        active: root.currentView === "clients"
                        onClicked: root.currentView = "clients"
                    }
                    SideButton {
                        Layout.fillWidth: true
                        icon: "󰒓"
                        label: "Tools"
                        badge: McpState.tools.length
                        active: root.currentView === "tools"
                        onClicked: root.currentView = "tools"
                    }
                    SideButton {
                        Layout.fillWidth: true
                        icon: "󰒋"
                        label: "Gateway"
                        active: root.currentView === "gateway"
                        onClicked: root.currentView = "gateway"
                    }

                    Item { Layout.fillHeight: true }

                    // Refresh button
                    SideButton {
                        Layout.fillWidth: true
                        icon: "󰑐"
                        label: "Refresh"
                        active: false
                        onClicked: McpState.refreshAll()
                    }

                    // Error / message strip
                    Text {
                        Layout.fillWidth: true
                        visible: McpState.lastError.length > 0
                        text: "" + McpState.lastError
                        color: Colors.error
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTiny
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: McpState.busy
                        text: "…working"
                        color: Colors.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTiny
                    }
                }
            }

            // ── divider ──────────────────────────────────────────
            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, Colors.dividerAlpha)
            }

            // ── content pane ─────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                CatalogView {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLarge
                    visible: root.currentView === "catalog"
                    onShowDetail: name => { McpState.inspectServer(name, false); root.currentView = "detail" }
                }

                ServersView {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLarge
                    visible: root.currentView === "servers"
                    onShowDetail: name => { McpState.inspectServer(name, false); root.currentView = "detail" }
                }

                ServerDetailView {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLarge
                    visible: root.currentView === "detail"
                    onBack: root.currentView = "servers"
                }

                ClientsView {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLarge
                    visible: root.currentView === "clients"
                }

                ToolsView {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLarge
                    visible: root.currentView === "tools"
                }

                GatewayView {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLarge
                    visible: root.currentView === "gateway"
                }
            }
        }
    }

    // ── side button inline component ─────────────────────────────
    component SideButton: GlassSurface {
        id: btn
        property string icon: ""
        property string label: ""
        property bool active: false
        property int badge: -1
        height: 34
        radius: Theme.radiusMedium
        level: "e1"; frost: true; frostAlpha: active ? 0.18 : 0.055
        interactive: true

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingLarge
            anchors.rightMargin: Theme.spacingNormal
            spacing: Theme.spacingNormal

            Text {
                text: btn.icon
                font.family: Theme.fontFamily
                font.pixelSize: 16
                color: btn.active ? Colors.accent : Colors.textMuted
            }
            Text {
                Layout.fillWidth: true
                text: btn.label
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontNormal
                font.bold: btn.active
                color: btn.active ? Colors.text : Colors.textMuted
                elide: Text.ElideRight
            }
            Rectangle {
                visible: btn.badge > 0
                Layout.preferredWidth: badgeText.implicitWidth + 12
                Layout.preferredHeight: 18
                radius: 9
                color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.3)
                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: btn.badge
                    color: Colors.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTiny
                    font.bold: true
                }
            }
        }

    }

    // ── keyboard ─────────────────────────────────────────────────
    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.visible = false
                event.accepted = true
            }
        }
    }
}
