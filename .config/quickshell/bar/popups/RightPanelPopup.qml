import QtQuick
import "../.."
import "../panels"
import Quickshell

PopupWindow {
    id: root

    // ── Required properties ─────────────────────────────────────
    property var bar              // the PanelWindow this popup attaches to
    property Item anchorItem      // pill rectangle for x/width
    property bool pinnedOpen: false
    property bool pillHovered: false

    signal pinnedClosed()         // emitted when user clicks outside

    // Internal: visibility tied to slide animation
    property bool popupVisible: false

    visible: popupVisible
    color: "transparent"
    implicitWidth: anchorItem ? anchorItem.width : 0
    implicitHeight: panelOuter.implicitHeight

    anchor.window: bar
    anchor.rect.x: anchorItem ? anchorItem.x : 0
    anchor.rect.y: bar ? bar.implicitHeight - 4 : 0
    anchor.rect.width: anchorItem ? anchorItem.width : 0
    anchor.rect.height: 0

    // ── Slide animation orchestration ────────────────────────────
    Connections {
        target: ControlState
        function onRightPanelChanged() {
            if (ControlState.rightPanel !== "none") {
                if (!root.popupVisible) {
                    root.popupVisible = true
                    panelOuter.y = -panelOuter.implicitHeight
                    cornerDelay.start()
                }
                // switching panels: Loader swaps content, no re-anim
            } else {
                cornerDelay.stop()
                panelSlideUp.start()
            }
        }
    }

    Timer {
        id: cornerDelay
        interval: 90  // wait for bar pill corners to flatten (~100ms)
        onTriggered: panelSlideDown.start()
    }

    NumberAnimation {
        id: panelSlideDown
        target: panelOuter; property: "y"
        to: 0; duration: Theme.durSlide; easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: panelSlideUp
        NumberAnimation {
            target: panelOuter; property: "y"
            to: -panelOuter.implicitHeight
            duration: Theme.durNormal; easing.type: Easing.InCubic
        }
        ScriptAction { script: root.popupVisible = false }
    }

    // ── Auto-close when no hover ─────────────────────────────────
    Timer {
        id: closeTimer
        interval: 220
        onTriggered: {
            if (!root.pinnedOpen && !root.pillHovered && !panelPopupHover.hovered)
                ControlState.rightPanel = "none"
        }
    }

    onPillHoveredChanged: {
        if (!pillHovered) closeTimer.restart()
        else closeTimer.stop()
    }

    HoverHandler {
        id: panelPopupHover
        onHoveredChanged: {
            if (!hovered) closeTimer.restart()
            else closeTimer.stop()
        }
    }

    // ── Click-outside dismiss ────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        onClicked: { root.pinnedClosed(); ControlState.rightPanel = "none" }
    }

    // ── Panel surface ────────────────────────────────────────────
    Rectangle {
        id: panelOuter
        y: 0
        width: anchorItem ? anchorItem.width : 0
        implicitHeight: panelContent.implicitHeight + 16
        topLeftRadius: 0; topRightRadius: 0
        bottomLeftRadius: Theme.radiusMedium; bottomRightRadius: Theme.radiusMedium
        color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, Colors.popupBgAlpha)
        border.width: 0
        clip: true

        // Side + bottom borders (no top → seamless join with pill)
        Rectangle {
            anchors.left: parent.left; anchors.top: parent.top
            anchors.bottom: parent.bottom; anchors.bottomMargin: 11
            width: 1
            color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.pillBorderAlpha)
        }
        Rectangle {
            anchors.right: parent.right; anchors.top: parent.top
            anchors.bottom: parent.bottom; anchors.bottomMargin: 11
            width: 1
            color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.pillBorderAlpha)
        }
        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 11; anchors.rightMargin: 11
            height: 1
            color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.pillBorderAlpha)
        }

        // Consume clicks (don't bubble to dismiss layer)
        MouseArea { anchors.fill: parent }

        // Escape key
        Item {
            focus: root.popupVisible
            Keys.onEscapePressed: { root.pinnedClosed(); ControlState.rightPanel = "none" }
        }

        Item {
            id: panelContent
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.panelPadding }
            implicitHeight: loader.implicitHeight

            Loader {
                id: loader
                anchors { left: parent.left; right: parent.right; top: parent.top }
                sourceComponent: {
                    switch (ControlState.rightPanel) {
                        case "audio":     return audioComp
                        case "battery":   return batteryComp
                        case "notif":     return notifComp
                        case "clock":     return calendarComp
                        case "wifi":      return wifiComp
                        case "bluetooth": return btComp
                        default:          return null
                    }
                }
            }

            Component { id: audioComp;    AudioPanel {} }
            Component { id: batteryComp;  BatteryPanel {} }
            Component { id: notifComp;    NotifPanel {} }
            Component { id: calendarComp; CalendarPanel {} }
            Component { id: wifiComp;     WifiPanel {} }
            Component { id: btComp;       BluetoothPanel {} }
        }
    }
}
