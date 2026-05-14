import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services/performance"
import Quickshell
import Quickshell.Wayland

// Top-edge slide-down performance dashboard. ~720px wide, center-anchored.
// Straight top corners (panel slides down from screen edge), rounded bottom.
PanelWindow {
    id: root

    property bool open: false

    readonly property int panelWidth: 720
    readonly property int hiddenOffsetY: -100  // start above the visible area

    visible: open || closeAnim.running
    color: "transparent"
    exclusiveZone: 0
    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.namespace: "qs-popup"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Native compositor blur tracks the slide-down transform.
    BackgroundEffect.blurRegion: Region {
        x: panelRect.x
        y: panelRect.y + slideTransform.y
        width: panelRect.width
        height: panelRect.height
        bottomLeftRadius: Theme.radiusLarge
        bottomRightRadius: Theme.radiusLarge
    }

    onOpenChanged: {
        if (open) {
            backdrop.opacity = 0
            slideTransform.y = root.hiddenOffsetY
            openAnim.start()
            Qt.callLater(() => scope.forceActiveFocus())
        } else {
            closeAnim.start()
        }
    }

    function close() { ControlState.perfPanelOpen = false }

    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: slideTransform; property: "y"
            to: 0; duration: Theme.durSlide; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: backdrop; property: "opacity"
            from: 0; to: 1; duration: Theme.durNormal; easing.type: Easing.OutCubic
        }
    }
    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation {
                target: slideTransform; property: "y"
                to: root.hiddenOffsetY
                duration: Theme.durNormal; easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: backdrop; property: "opacity"
                to: 0; duration: Theme.durNormal; easing.type: Easing.InCubic
            }
        }
    }

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "transparent"
        opacity: 0
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.close()
                event.accepted = true
            }
        }

        Rectangle {
            id: panelRect
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.barExclusiveZone + 4
            width: root.panelWidth
            implicitHeight: contentCol.implicitHeight + Theme.panelPadding * 2

            transform: Translate { id: slideTransform; y: root.hiddenOffsetY }
            color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, Colors.popupBgAlpha)
            border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.pillBorderAlpha)
            border.width: 1

            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: Theme.radiusLarge
            bottomRightRadius: Theme.radiusLarge
            clip: true

            // Consume clicks (don't pass through to backdrop)
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: contentCol
                anchors {
                    left: parent.left; right: parent.right; top: parent.top
                    margins: Theme.panelPadding
                }
                spacing: Theme.spacingNormal

                // ── Header ──────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSmall
                    Text {
                        text: "Performance"
                        color: Colors.text
                        font.pixelSize: Theme.fontLarge
                        font.family: Theme.fontFamily
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "Mod+H to toggle pill • Esc to close"
                        color: Colors.textMuted
                        font.pixelSize: Theme.fontSmall
                        font.family: Theme.fontFamily
                    }
                }

                // ── Card grid (2 columns) ───────────────────────
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: Theme.spacingNormal
                    columnSpacing: Theme.spacingNormal

                    // CPU
                    PerfCard {
                        Layout.fillWidth: true
                        title: "CPU"
                        icon: ""
                        bigValue: Math.round(PerfState.cpuPercent * 100) + "%"
                        subValue: {
                            const t = PerfState.cpuTemp
                            return t !== null ? t.toFixed(0) + "°C" : ""
                        }
                        subColor: {
                            const t = PerfState.cpuTemp
                            if (t === null) return Colors.textMuted
                            if (t >= 85) return Colors.error
                            if (t >= 70) return Colors.warning
                            return Colors.textMuted
                        }
                        sparkValues: PerfState.cpuHistory
                        sparkMax: 1.0
                    }

                    // RAM
                    PerfCard {
                        Layout.fillWidth: true
                        title: "RAM"
                        icon: ""
                        bigValue: Math.round(PerfState.memPercent * 100) + "%"
                        subValue: PerfState.formatBytes(PerfState.memUsed)
                                + " / " + PerfState.formatBytes(PerfState.memTotal)
                        sparkValues: PerfState.memHistory
                        sparkMax: 1.0
                    }

                    // GPU
                    PerfCard {
                        Layout.fillWidth: true
                        visible: PerfState.gpuPresent
                        title: "GPU" + (PerfState.gpuBackend ? " (" + PerfState.gpuBackend + ")" : "")
                        icon: "󰢮"
                        bigValue: PerfState.gpuBusy === null
                            ? "—"
                            : Math.round(PerfState.gpuBusy * 100) + "%"
                        subValue: {
                            const parts = []
                            if (PerfState.gpuTemp !== null) parts.push(PerfState.gpuTemp.toFixed(0) + "°C")
                            if (PerfState.gpuMemTotal && PerfState.gpuMemUsed !== null) {
                                parts.push(PerfState.formatBytes(PerfState.gpuMemUsed)
                                         + " / " + PerfState.formatBytes(PerfState.gpuMemTotal))
                            } else if (PerfState.gpuBackend === "intel") {
                                parts.push("freq ratio")
                            }
                            return parts.join("  ·  ")
                        }
                        sparkValues: PerfState.gpuHistory
                        sparkMax: 1.0
                    }

                    // Temps
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: tempsCol.implicitHeight + Theme.panelPadding * 2
                        radius: Theme.radiusMedium
                        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.18)
                        border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.pillBorderAlpha * 0.6)
                        border.width: 1

                        ColumnLayout {
                            id: tempsCol
                            anchors {
                                left: parent.left; right: parent.right; top: parent.top
                                margins: Theme.panelPadding
                            }
                            spacing: Theme.spacingTight

                            Row {
                                spacing: Theme.spacingSmall
                                Text {
                                    text: ""
                                    color: Colors.accent
                                    font.pixelSize: Theme.fontMedium
                                    font.family: Theme.fontFamily
                                }
                                Text {
                                    text: "Temps"
                                    color: Colors.textMuted
                                    font.pixelSize: Theme.fontSmall
                                    font.family: Theme.fontFamily
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Repeater {
                                // Group temps by hwmon name; show max per group → keeps card compact.
                                model: {
                                    const groups = {}
                                    for (const t of PerfState.temps) {
                                        if (!(t.name in groups) || t.value > groups[t.name].value) {
                                            groups[t.name] = t
                                        }
                                    }
                                    return Object.values(groups)
                                }
                                delegate: RowLayout {
                                    Layout.fillWidth: true
                                    required property var modelData
                                    spacing: Theme.spacingSmall
                                    Text {
                                        text: modelData.name
                                        color: Colors.text
                                        font.pixelSize: Theme.fontSmall
                                        font.family: Theme.fontFamily
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: modelData.value.toFixed(0) + "°C"
                                        color: {
                                            const v = modelData.value
                                            if (v >= 85) return Colors.error
                                            if (v >= 70) return Colors.warning
                                            return Colors.text
                                        }
                                        font.pixelSize: Theme.fontSmall
                                        font.family: Theme.fontFamily
                                    }
                                }
                            }
                        }
                    }

                    // Network
                    PerfCard {
                        Layout.fillWidth: true
                        title: "Net" + (PerfState.netIface ? " (" + PerfState.netIface + ")" : "")
                        icon: "󰈀"
                        bigValue: "↓ " + PerfState.formatKbps(PerfState.netRxKbps)
                        subValue: "↑ " + PerfState.formatKbps(PerfState.netTxKbps)
                        sparkValues: PerfState.netRxHistory
                        sparkMax: 1
                        sparkAutoScale: true
                        sparkSecondaryValues: PerfState.netTxHistory
                    }

                    // Disk
                    PerfCard {
                        Layout.fillWidth: true
                        title: "Disk"
                        icon: "󰋊"
                        bigValue: "R " + PerfState.formatKbps(PerfState.diskReadKbps)
                        subValue: "W " + PerfState.formatKbps(PerfState.diskWriteKbps)
                        sparkValues: PerfState.diskReadHistory
                        sparkMax: 1
                        sparkAutoScale: true
                        sparkSecondaryValues: PerfState.diskWriteHistory
                    }
                }
            }
        }
    }
}
