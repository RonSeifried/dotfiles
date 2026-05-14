import QtQuick
import "../.."
import "../panels"
import Quickshell
import Quickshell.Wayland

PopupWindow {
    id: root

    // ── Required properties ─────────────────────────────────────
    property var bar              // the PanelWindow this popup attaches to
    property Item anchorItem      // pill rectangle for x/width
    // Name of the currently click-pinned panel ("" = none). Pin applies only
    // when it matches the panel value this popup is currently rendering, so
    // hovering across pills won't extend a pin onto an unrelated panel.
    property string pinnedPanel: ""
    property bool pillHovered: false

    readonly property bool isPinned: pinnedPanel.length > 0
        && pinnedPanel === ControlState.rightPanel
        && _isHandled

    // True while a TextInput (or any item exposing a blinking cursor) inside
    // the popup has keyboard focus. Prevents hover-out from closing the panel
    // mid-typing (e.g. WifiPanel password entry).
    readonly property bool keyboardActive: !!(activeFocusItem
        && activeFocusItem.cursorVisible === true)
    // Mouse over panel surface — used by bar to gate ToplevelManager close.
    readonly property bool panelHovered: panelPopupHover.hovered

    signal pinnedClosed()         // emitted when user clicks outside

    // Internal: visibility tied to slide animation
    property bool popupVisible: false

    visible: popupVisible
    color: "transparent"
    implicitWidth: anchorItem ? anchorItem.width : 0
    implicitHeight: panelOuter.implicitHeight

    // Native compositor blur (ext-background-effect-v1, qs 0.3 + niri 26.04).
    // Tracks the panel's vertical slide animation via explicit y-binding;
    // qs polish-phase update only fires on PendingRegion changes.
    BackgroundEffect.blurRegion: Region {
        x: panelOuter.x
        y: panelOuter.y
        width: panelOuter.width
        height: panelOuter.implicitHeight
        bottomLeftRadius: Theme.radiusMedium
        bottomRightRadius: Theme.radiusMedium
    }

    anchor.window: bar
    anchor.rect.x: anchorItem ? anchorItem.x : 0
    anchor.rect.y: bar ? bar.implicitHeight - 4 : 0
    anchor.rect.width: anchorItem ? anchorItem.width : 0
    anchor.rect.height: 0

    // ── Slide animation orchestration ────────────────────────────
    // Multi-monitor: only react if my bar's screen is the active one.
    readonly property bool _onActiveScreen: bar && bar.screen
        && bar.screen.name === ControlState.activeScreen
    // Panels handled by this (right-cluster) popup. "mpris" belongs to MprisPopup.
    readonly property var _handled: ["notif","audio","battery","wifi","bluetooth","clock"]
    readonly property bool _isHandled: _handled.indexOf(ControlState.rightPanel) !== -1

    Connections {
        target: ControlState
        function onRightPanelChanged() {
            if (root._isHandled && root._onActiveScreen) {
                if (!root.popupVisible) {
                    root.popupVisible = true
                    panelOuter.y = -panelOuter.implicitHeight
                    cornerDelay.start()
                }
                // switching panels: Loader swaps content, no re-anim
            } else {
                // closing globally, another popup took over, or another screen → retract.
                if (root.popupVisible) {
                    cornerDelay.stop()
                    panelSlideUp.start()
                }
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
    // Auto-close timer. Short delay for hover-only; longer grace when pinned
    // so user can step away briefly without losing the panel.
    Timer {
        id: closeTimer
        interval: root.isPinned ? 4000 : 220
        onTriggered: {
            if (root.pillHovered || panelPopupHover.hovered || root.keyboardActive) return
            if (root.isPinned) root.pinnedClosed()  // bar clears pinnedPanel
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

        // Side + bottom borders (no top → seamless join with pill).
        // Margins match radiusMedium so the 1px line meets the corner curve tangentially.
        Rectangle {
            anchors.left: parent.left; anchors.top: parent.top
            anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.radiusMedium
            width: 1
            color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.pillBorderAlpha)
        }
        Rectangle {
            anchors.right: parent.right; anchors.top: parent.top
            anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.radiusMedium
            width: 1
            color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.pillBorderAlpha)
        }
        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Theme.radiusMedium; anchors.rightMargin: Theme.radiusMedium
            height: 1
            color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.pillBorderAlpha)
        }

        // Consume clicks so they don't bubble to whatever is below the popup window.
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
