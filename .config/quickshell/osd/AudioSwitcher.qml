import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"

PanelWindow {
    id: root
    property bool open: false
    property int selectedIndex: 0
    readonly property var routes: {
        const out = []
        for (const n of AudioState.sinks)
            out.push(({ node: n, type: "output", label: AudioState.sinkLabel(n), icon: "󰓃" }))
        for (const n of AudioState.sources)
            out.push(({ node: n, type: "input", label: AudioState.sourceLabel(n), icon: "󰍬" }))
        return out
    }

    visible: open
    color: "transparent"; exclusiveZone: 0
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.namespace: "qs-audio-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onOpenChanged: if (open) { selectedIndex = 0; scope.forceActiveFocus() }
    function close() { ControlState.audioSwitcherOpen = false }
    function activate() {
        const route = routes[selectedIndex]
        if (!route) return
        if (route.type === "output") AudioState.setSink(route.node)
        else AudioState.setSource(route.node)
        close()
    }

    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.14); MouseArea { anchors.fill: parent; onClicked: root.close() } }
    FocusScope {
        id: scope; anchors.fill: parent
        Keys.onEscapePressed: root.close()
        Keys.onUpPressed: root.selectedIndex = Math.max(0, root.selectedIndex - 1)
        Keys.onDownPressed: root.selectedIndex = Math.min(root.routes.length - 1, root.selectedIndex + 1)
        Keys.onReturnPressed: root.activate()
        Keys.onEnterPressed: root.activate()

        Rectangle {
            width: Math.min(420, parent.width - 32)
            height: Math.min(routesCol.implicitHeight + 24, parent.height - 80)
            anchors.centerIn: parent; color: "transparent"; radius: Theme.radiusXL; clip: true
            GlassSurface { anchors.fill: parent; level: "e3"; radius: Theme.radiusXL }
            MouseArea { anchors.fill: parent }
            Column {
                id: routesCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: Theme.spacingSmall
                Text {
                    text: "Audio Routes"; color: Colors.text
                    font.pixelSize: Theme.fontMedium; font.bold: true; font.family: Theme.fontFamily
                }
                Repeater {
                    model: root.routes
                    delegate: Rectangle {
                        id: routeRow
                        required property var modelData
                        required property int index
                        width: routesCol.width; height: 48; radius: Theme.radiusMedium
                        readonly property bool current: modelData.type === "output"
                            ? AudioState.sink === modelData.node : AudioState.source === modelData.node
                        color: root.selectedIndex === index ? Qt.rgba(1, 1, 1, 0.14)
                            : current ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.16)
                            : Qt.rgba(1, 1, 1, 0.04)
                        Row {
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                            spacing: Theme.spacingNormal
                            Text { text: routeRow.modelData.icon; color: routeRow.current ? Colors.accent : Colors.textMuted; font.pixelSize: Theme.fontLarge; font.family: Theme.fontIcon }
                            Column {
                                width: parent.width - 54; spacing: 1
                                Text { width: parent.width; text: routeRow.modelData.label; color: Colors.text; font.pixelSize: Theme.fontNormal; font.family: Theme.fontFamily; elide: Text.ElideRight }
                                Text { text: routeRow.modelData.type === "output" ? "Output" : "Input"; color: Colors.textMuted; font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily }
                            }
                            Text { visible: routeRow.current; text: "󰄬"; color: Colors.accent; font.pixelSize: Theme.fontMedium; font.family: Theme.fontIcon }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onEntered: root.selectedIndex = routeRow.index; hoverEnabled: true; onClicked: root.activate() }
                    }
                }
            }
        }
    }
}
