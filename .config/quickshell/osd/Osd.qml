import QtQuick
import ".."
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property string type: "volume"
    property real value: 0
    property bool muted: false
    property bool showing: false
    property bool active: true   // false = this screen is not the focus target, ignore signals

    readonly property int panelWidth: 64
    readonly property int panelHeight: 220
    readonly property int hiddenOffset: panelWidth + 4

    visible: showing || hideAnim.running
    color: "transparent"
    exclusiveZone: 0

    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.namespace: "qs-popup"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Native compositor blur (ext-background-effect-v1). Tracks slide-in via
    // explicit x-binding to slideTransform.x (qs doesn't poll transforms).
    BackgroundEffect.blurRegion: Region {
        x: osdRect.x + slideTransform.x
        y: osdRect.y
        width: osdRect.width
        height: osdRect.height
        topLeftRadius: Theme.radiusLarge
        bottomLeftRadius: Theme.radiusLarge
    }

    Connections {
        target: ControlState
        function onOsdVolumeRequested(v, m) { if (root.active) root.showVolume(v, m) }
        function onOsdBrightnessRequested(v) { if (root.active) root.showBrightness(v) }
    }

    function showVolume(v, m) { type = "volume"; value = v; muted = m === true; _appear() }
    function showBrightness(v) { type = "brightness"; value = v; muted = false; _appear() }

    function _appear() {
        if (hideAnim.running) hideAnim.stop()
        if (!showing) showing = true
        showAnim.restart()
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: hideAnim.start()
    }

    NumberAnimation {
        id: showAnim
        target: slideTransform; property: "x"
        to: 0
        duration: Theme.durSlide; easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: hideAnim
        NumberAnimation {
            target: slideTransform; property: "x"
            to: root.hiddenOffset
            duration: Theme.durNormal; easing.type: Easing.InCubic
        }
        ScriptAction { script: root.showing = false }
    }

    Rectangle {
        id: osdRect
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.panelWidth
        height: root.panelHeight
        color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, Theme.elevation.e2TintAlpha)
        border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Theme.elevation.e1BorderAlpha)
        border.width: 1

        // Two rounded corners on left, straight on right (slide-in edge)
        topLeftRadius: Theme.radiusLarge
        bottomLeftRadius: Theme.radiusLarge
        topRightRadius: 0
        bottomRightRadius: 0

        clip: true

        transform: Translate { id: slideTransform; x: root.hiddenOffset }

        ColumnLayout {
            anchors {
                left: parent.left; right: parent.right
                top: parent.top; bottom: parent.bottom
                topMargin: 14; bottomMargin: 12
                leftMargin: 8; rightMargin: 8
            }
            spacing: 10

            // ── Icon (top) ──────────────────────────────────────
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.type === "volume"
                    ? (root.muted ? "󰝟" : root.value <= 0 ? "󰖁" : root.value < 0.34 ? "󰕿" : root.value < 0.67 ? "󰖀" : "󰕾")
                    : "󰃠"
                color: root.muted ? Colors.warning : Colors.accent
                font.pixelSize: 22
                font.family: Theme.fontFamily
                Behavior on color { ColorAnimation { duration: Theme.durFast } }
            }

            // ── Vertical bar (fills bottom-up) ──────────────────
            Rectangle {
                id: barTrack
                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: true
                width: 8
                radius: 4
                color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.sliderTrackAlpha)

                Rectangle {
                    id: barFill
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: parent.height * Math.min(1, Math.max(0, root.value))
                    radius: parent.radius
                    color: root.muted ? Colors.textMuted : Colors.accent

                    Behavior on height {
                        NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutQuad }
                    }
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                }
            }

            // ── Percent label (bottom) ──────────────────────────
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.muted ? "M" : Math.round(Math.min(1, Math.max(0, root.value)) * 100)
                color: root.muted ? Colors.textMuted : Colors.text
                font.pixelSize: Theme.fontSmall; font.bold: true
                font.family: Theme.fontFamily
            }
        }
    }
}
