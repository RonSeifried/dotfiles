import QtQuick
import "../.."
import "../../components"
import "../panels"
import Quickshell
import Quickshell.Wayland

// Slide-down popup anchored to the bar's MPRIS pill — the last hover-driven
// bar dropdown (everything else moved into the Control Center). Panel width =
// pill width so corners join seamlessly: pill bottom corners flatten when
// open, panel top corners stay square.
PopupWindow {
    id: root

    property var bar
    property Item anchorItem
    // Name of currently click-pinned panel; pin applies only when it matches "mpris".
    property string pinnedPanel: ""
    property bool pillHovered: false

    readonly property bool isPinned: pinnedPanel === "mpris"
        && ControlState.rightPanel === "mpris"
    // The compact media panel has no text controls, so hover/pin state is the
    // complete closing model. Keeping this explicit avoids querying focus on
    // PopupWindow, which does not expose an activeFocusItem of its own.
    readonly property bool keyboardActive: false
    readonly property bool panelHovered: panelPopupHover.hovered

    signal pinnedClosed()

    property bool popupVisible: false

    visible: popupVisible
    color: "transparent"
    // Floor on width so the 180px cover + padding always fits even when the
    // pill is narrower than the panel body (short titles).
    readonly property int panelWidth: anchorItem ? Math.max(anchorItem.width, 300) : 300
    implicitWidth: panelWidth
    implicitHeight: Theme.popupGap + panelOuter.implicitHeight

    BackgroundEffect.blurRegion: Region {
        x: panelOuter.x
        y: panelOuter.y
        width: panelOuter.width
        height: panelOuter.implicitHeight
        topLeftRadius: Theme.radiusXL
        topRightRadius: Theme.radiusXL
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
    anchor.rect.y: bar ? bar.implicitHeight : 0
    anchor.rect.width: panelWidth
    anchor.rect.height: 0

    readonly property bool _onActiveScreen: bar && bar.screen
        && bar.screen.name === ControlState.activeScreen
    readonly property bool shouldShow: ControlState.rightPanel === "mpris" && _onActiveScreen

    onShouldShowChanged: {
        if (shouldShow) {
            if (!popupVisible) {
                popupVisible = true
                panelOuter.y = -8
                panelOuter.opacity = 0
                panelSlideDown.start()
            }
        } else if (popupVisible) {
            panelSlideUp.start()
        }
    }
    // Other-screen takeover: my pill remains "mpris" but activeScreen flipped → retract.
    Connections {
        target: ControlState
        function onActiveScreenChanged() {
            if (root.popupVisible && !root.shouldShow) {
                root.panelSlideUp.start()
            }
        }
    }

    ParallelAnimation {
        id: panelSlideDown
        NumberAnimation { target: panelOuter; property: "y"; to: Theme.popupGap; duration: Theme.durNormal; easing.type: Easing.OutCubic }
        NumberAnimation { target: panelOuter; property: "opacity"; to: 1; duration: Theme.durNormal; easing.type: Easing.OutCubic }
    }

    SequentialAnimation {
        id: panelSlideUp
        NumberAnimation {
            target: panelOuter; property: "y"
            to: -8
            duration: Theme.durFast; easing.type: Easing.InCubic
        }
        NumberAnimation { target: panelOuter; property: "opacity"; to: 0; duration: Theme.durFast }
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
        color: "transparent"
        clip: true

        radius: Theme.radiusXL
        GlassSurface {
            anchors.fill: parent
            level: "e3"
            radius: Theme.radiusXL
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
