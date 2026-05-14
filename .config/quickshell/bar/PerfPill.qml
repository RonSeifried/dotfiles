import QtQuick
import ".."
import "../services/performance"

// Compact CPU% pill with inline sparkline. Click → toggle PerfPanel.
//
// Hidden by default; `ControlState.perfPillVisible` toggle (Mod+H) shows it.
// When the panel is open the pill flattens its bottom corners — but the
// PerfPanel slides down from the screen top edge, NOT from the bar — so the
// "seamless join" pattern from right-cluster pills doesn't apply. We keep
// full rounded pills for the perf cluster.
Rectangle {
    id: root

    required property var bar

    readonly property bool show: ControlState.perfPillVisible

    implicitHeight: Theme.pillHeight
    implicitWidth: show ? content.implicitWidth + 18 : 0
    radius: Theme.radiusPill
    color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, Colors.pillBgAlpha)
    border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.pillBorderAlpha)
    border.width: 1
    opacity: show ? 1 : 0
    clip: true
    visible: implicitWidth > 1
    Behavior on implicitWidth { NumberAnimation { duration: Theme.durSlide; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutCubic } }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            ControlState.activeScreen = root.bar.screen.name
            ControlState.perfPanelOpen = !ControlState.perfPanelOpen
        }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Theme.spacingSmall

        // CPU glyph
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ""
            color: Colors.accent
            font.pixelSize: Theme.fontMedium
            font.family: Theme.fontFamily
        }

        // CPU %
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(PerfState.cpuPercent * 100) + "%"
            color: Colors.text
            font.pixelSize: Theme.fontMedium
            font.family: Theme.fontFamily
        }

        // Mini sparkline — last 30 samples of CPU history.
        Sparkline {
            anchors.verticalCenter: parent.verticalCenter
            width: 56; height: Theme.pillHeight - 12
            values: PerfState.cpuHistory.slice(-30)
            maxValue: 1.0
            strokeColor: Colors.accent
            fillColor: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.22)
            strokeWidth: 1.2
        }
    }
}
