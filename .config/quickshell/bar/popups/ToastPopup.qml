import QtQuick
import "../.."
import Quickshell

PopupWindow {
    id: root

    property var bar
    property Item anchorItem

    property bool toastVisible: false
    property var toastNotif: null

    visible: toastVisible
    color: "transparent"
    implicitWidth: anchorItem ? anchorItem.width : 0
    implicitHeight: toastOuter.implicitHeight

    anchor.window: bar
    anchor.rect.x: anchorItem ? anchorItem.x : 0
    anchor.rect.y: bar ? bar.implicitHeight - 4 : 0
    anchor.rect.width: anchorItem ? anchorItem.width : 0
    anchor.rect.height: 0

    // Multi-monitor: only the focused screen shows the toast.
    Connections {
        target: NotifState
        function onToastRequested(notif) {
            if (root.bar && root.bar.screen
                && root.bar.screen.name === NiriState.focusedOutput) {
                root.showToast(notif)
            }
        }
    }

    Timer {
        id: dismissTimer
        interval: 5000
        running: root.toastVisible
        onTriggered: root.hideToast()
    }

    function showToast(entry) {
        toastNotif = entry
        toastVisible = true
        toastOuter.y = -toastOuter.implicitHeight
        slideDown.start()
        dismissTimer.restart()
    }

    function hideToast() { slideUp.start() }

    NumberAnimation {
        id: slideDown
        target: toastOuter; property: "y"
        to: 0; duration: Theme.durSlide; easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: slideUp
        NumberAnimation {
            target: toastOuter; property: "y"
            to: -toastOuter.implicitHeight
            duration: Theme.durNormal; easing.type: Easing.InCubic
        }
        ScriptAction { script: root.toastVisible = false }
    }

    Rectangle {
        id: toastOuter
        y: 0
        width: anchorItem ? anchorItem.width : 0
        implicitHeight: toastCol.implicitHeight + 18
        topLeftRadius: 0; topRightRadius: 0
        bottomLeftRadius: Theme.radiusMedium; bottomRightRadius: Theme.radiusMedium
        color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, Colors.popupBgAlpha)
        border.width: 0
        clip: true

        // Side + bottom borders
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
                    width: parent.width - 14; elide: Text.ElideRight
                }
                Text {
                    text: "✕"; color: Colors.textMuted; font.pixelSize: Theme.fontSmall
                    font.family: Theme.fontFamily
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.hideToast() }
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
                        // Hide FDO "default" — that's click-on-notif activation, not a labeled button.
                        visible: modelData.identifier !== "default"
                        implicitWidth: toastActionLabel.implicitWidth + 16
                        implicitHeight: toastActionLabel.implicitHeight + 8
                        radius: Theme.radiusTiny
                        color: toastActionMa.containsMouse
                            ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.25)
                            : Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.12)
                        border.width: 1
                        border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.3)

                        Behavior on color { ColorAnimation { duration: Theme.durHover } }

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
