import QtQuick
import "../.."
import "../panels"
import Quickshell
import Quickshell.Wayland

// Slide-down popup anchored to the bar's MPRIS pill. Same blur/anim machinery
// as RightPanelPopup. Panel width = pill width so corners join seamlessly:
// pill bottom corners flatten when open, panel top corners stay square.
PopupWindow {
    id: root

    property var bar
    property Item anchorItem
    // Name of currently click-pinned panel; pin applies only when it matches "mpris".
    property string pinnedPanel: ""
    property bool pillHovered: false

    readonly property bool isPinned: pinnedPanel === "mpris"
        && ControlState.rightPanel === "mpris"
    // Keep panel open while a TextInput inside has focus (no inputs today,
    // but mirrors RightPanelPopup so future panel additions just work).
    readonly property bool keyboardActive: !!(activeFocusItem
        && activeFocusItem.cursorVisible === true)
    readonly property bool panelHovered: panelPopupHover.hovered

    signal pinnedClosed()

    property bool popupVisible: false

    visible: popupVisible
    color: "transparent"
    // Floor on width so the 180px cover + padding always fits even when the
    // pill is narrower than the panel body (short titles).
    readonly property int panelWidth: anchorItem ? Math.max(anchorItem.width, 220) : 220
    implicitWidth: panelWidth
    implicitHeight: panelOuter.implicitHeight

    BackgroundEffect.blurRegion: Region {
        x: panelOuter.x
        y: panelOuter.y
        width: panelOuter.width
        height: panelOuter.implicitHeight
        bottomLeftRadius: Theme.radiusMedium
        bottomRightRadius: Theme.radiusMedium
    }

    anchor.window: bar
    // Center the (wider) popup under the (narrower) pill, clamped to bar bounds.
    anchor.rect.x: {
        if (!anchorItem || !bar) return 0
        const raw = anchorItem.x + (anchorItem.width - panelWidth) / 2
        const max = bar.width - panelWidth
        return Math.max(0, Math.min(raw, max))
    }
    anchor.rect.y: bar ? bar.implicitHeight - 4 : 0
    anchor.rect.width: panelWidth
    anchor.rect.height: 0

    readonly property bool _onActiveScreen: bar && bar.screen
        && bar.screen.name === ControlState.activeScreen
    readonly property bool shouldShow: ControlState.rightPanel === "mpris" && _onActiveScreen

    onShouldShowChanged: {
        if (shouldShow) {
            if (!popupVisible) {
                popupVisible = true
                panelOuter.y = -panelOuter.implicitHeight
                cornerDelay.start()
            }
        } else if (popupVisible) {
            cornerDelay.stop()
            panelSlideUp.start()
        }
    }
    // Other-screen takeover: my pill remains "mpris" but activeScreen flipped → retract.
    Connections {
        target: ControlState
        function onActiveScreenChanged() {
            if (root.popupVisible && !root.shouldShow) {
                root.cornerDelay.stop()
                root.panelSlideUp.start()
            }
        }
    }

    Timer {
        id: cornerDelay
        interval: 90
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

    // Auto-close timer. Short delay for hover-only; longer grace when pinned.
    Timer {
        id: closeTimer
        interval: root.isPinned ? 4000 : 220
        onTriggered: {
            if (root.pillHovered || panelPopupHover.hovered || root.keyboardActive) return
            if (root.isPinned) root.pinnedClosed()
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

    // Panel surface — top flat (joins pill seamlessly), bottom rounded.
    // Borders drawn as 1px rects on sides + bottom so they meet the pill's
    // bottom border without a doubled line on top.
    Rectangle {
        id: panelOuter
        y: 0
        width: parent.width
        implicitHeight: panelContent.implicitHeight + 2 * Theme.panelPadding
        topLeftRadius: 0; topRightRadius: 0
        bottomLeftRadius: Theme.radiusMedium; bottomRightRadius: Theme.radiusMedium
        color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, Theme.elevation.e2TintAlpha)
        border.width: 0
        clip: true

        Rectangle {
            anchors.left: parent.left; anchors.top: parent.top
            anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.radiusMedium
            width: 1
            color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Theme.elevation.e1BorderAlpha)
        }
        Rectangle {
            anchors.right: parent.right; anchors.top: parent.top
            anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.radiusMedium
            width: 1
            color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Theme.elevation.e1BorderAlpha)
        }
        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Theme.radiusMedium; anchors.rightMargin: Theme.radiusMedium
            height: 1
            color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Theme.elevation.e1BorderAlpha)
        }

        MouseArea { anchors.fill: parent }

        Item {
            focus: root.popupVisible
            Keys.onEscapePressed: { root.pinnedClosed(); ControlState.rightPanel = "none" }
        }

        Item {
            id: panelContent
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.panelPadding }
            implicitHeight: mprisPanel.implicitHeight
            MprisPanel { id: mprisPanel }
        }
    }
}
