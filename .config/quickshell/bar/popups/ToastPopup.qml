import QtQuick
import "../.."
import "../../components"
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland

// On-screen notification toast: a floating glass card that drops in below the
// bar at the status cluster (top-right), auto-dismisses after 5s. Mirrors the
// Control Center's float (window touches the bar, the visible gap is an
// internal transparent strip) so there's no dead zone and the look is uniform.
PopupWindow {
    id: root

    property var bar
    property Item anchorItem

    property bool toastVisible: false
    property var toastNotif: null
    // FDO: critical notifications don't expire — they stay until acted on.
    readonly property bool critical: (toastNotif?.urgency ?? NotificationUrgency.Normal)
        === NotificationUrgency.Critical
    readonly property var defaultAction:
        (toastNotif?.actions ?? []).find(a => a.identifier === "default") || null

    readonly property int toastWidth: 340
    readonly property int gap: 6

    visible: toastVisible
    color: "transparent"
    implicitWidth: toastWidth
    implicitHeight: card.implicitHeight + gap

    BackgroundEffect.blurRegion: Region {
        x: card.x; y: card.y; width: card.width; height: card.implicitHeight
        topLeftRadius: Theme.radiusLarge; topRightRadius: Theme.radiusLarge
        bottomLeftRadius: Theme.radiusLarge; bottomRightRadius: Theme.radiusLarge
    }

    // Right edge flush with the bar's right edge (matches the Control Center).
    anchor.window: bar
    anchor.rect.x: bar ? bar.width - toastWidth : 0
    anchor.rect.y: bar ? bar.implicitHeight : 0
    anchor.rect.width: toastWidth
    anchor.rect.height: 0

    // Multi-monitor: only the focused screen shows the toast.
    Connections {
        target: NotifState
        function onToastRequested(notif) {
            if (root.bar && root.bar.screen
                && root.bar.screen.name === WMState.focusedOutput) {
                root.showToast(notif)
            }
        }
    }

    Timer {
        id: dismissTimer
        interval: 5000
        running: root.toastVisible && !cardHover.hovered && !root.critical
        onTriggered: root.hideToast()
    }

    function showToast(entry) {
        toastNotif = entry
        toastVisible = true
        card.y = root.gap - 8
        card.opacity = 0
        appearAnim.start()
        dismissTimer.restart()
    }
    function hideToast() { disappearAnim.start() }

    ParallelAnimation {
        id: appearAnim
        NumberAnimation { target: card; property: "y"; to: root.gap
            duration: Theme.durNormal; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "opacity"; to: 1
            duration: Theme.durNormal; easing.type: Easing.OutCubic }
    }
    SequentialAnimation {
        id: disappearAnim
        ParallelAnimation {
            NumberAnimation { target: card; property: "y"; to: root.gap - 8
                duration: Theme.durFast; easing.type: Easing.InCubic }
            NumberAnimation { target: card; property: "opacity"; to: 0
                duration: Theme.durFast; easing.type: Easing.InCubic }
        }
        ScriptAction { script: root.toastVisible = false }
    }

    HoverHandler { id: cardHover }

    Rectangle {
        id: card
        y: root.gap
        width: root.toastWidth
        implicitHeight: toastCol.implicitHeight + 2 * Theme.panelPadding
        radius: Theme.radiusLarge
        color: "transparent"
        clip: true

        GlassSurface { anchors.fill: parent; level: "e3"; frost: true; radius: Theme.radiusLarge }

        // Critical urgency: error hairline over the glass border (palette-driven
        // signal, same vocabulary as the lock's failed state).
        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusLarge
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.65)
            visible: root.critical
        }

        // Body click = default action (matches NotifCard in the CC deck).
        // Sits UNDER the text column so the ✕ and action chips still win.
        MouseArea {
            anchors.fill: parent
            enabled: !!root.defaultAction
            cursorShape: root.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                NotifState.invokeAction(root.toastNotif.id, root.defaultAction)
                root.hideToast()
            }
        }

        Column {
            id: toastCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.panelPadding }
            spacing: Theme.spacingTight

            Row {
                width: parent.width
                Text {
                    text: {
                        const s = root.toastNotif?.summary ?? ""
                        const a = root.toastNotif?.appName ?? ""
                        return s.length > 0 ? s : a
                    }
                    color: Colors.text; font.pixelSize: Theme.fontMedium; font.bold: true
                    font.family: Theme.fontFamily
                    width: parent.width - 16; elide: Text.ElideRight
                }
                Text {
                    text: "✕"; color: Colors.textMuted; font.pixelSize: Theme.fontSmall
                    font.family: Theme.fontFamily
                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.hideToast() }
                }
            }
            Text {
                visible: {
                    const s = root.toastNotif?.summary ?? ""
                    const a = root.toastNotif?.appName ?? ""
                    return a.length > 0 && a !== s
                }
                width: parent.width
                text: root.toastNotif?.appName ?? ""
                color: Colors.textMuted; font.pixelSize: Theme.fontSmall
                font.family: Theme.fontFamily; elide: Text.ElideRight
            }
            Text {
                visible: (root.toastNotif?.body ?? "").length > 0
                width: parent.width
                text: root.toastNotif?.body ?? ""
                color: Colors.textMuted; font.pixelSize: Theme.fontNormal
                font.family: Theme.fontFamily; wrapMode: Text.WordWrap
            }

            Flow {
                width: parent.width
                spacing: Theme.spacingSmall
                visible: (root.toastNotif?.actions?.length ?? 0) > 0
                topPadding: Theme.spacingTight

                Repeater {
                    model: root.toastNotif?.actions ?? []
                    delegate: Rectangle {
                        id: toastActionBtn
                        required property var modelData
                        visible: modelData.identifier !== "default"
                        implicitWidth: toastActionLabel.implicitWidth + 16
                        implicitHeight: toastActionLabel.implicitHeight + 8
                        // Chip per design language: accent-tinted fill, no border.
                        radius: Theme.radiusSmall
                        color: toastActionMa.containsMouse
                            ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.28)
                            : Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.18)
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }

                        Text {
                            id: toastActionLabel
                            anchors.centerIn: parent
                            text: modelData.text || modelData.identifier
                            color: Colors.text
                            font.pixelSize: Theme.fontSmall
                            font.family: Theme.fontFamily
                        }
                        MouseArea {
                            id: toastActionMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                NotifState.invokeAction(root.toastNotif.id, toastActionBtn.modelData)
                                root.hideToast()
                            }
                        }
                    }
                }
            }
        }
    }
}
