import QtQuick
import "../.."

Column {
    id: root
    spacing: Theme.spacingSmall
    anchors { left: parent?.left; right: parent?.right }

    Row {
        width: parent.width
        Text {
            text: "Notifications"; color: Colors.text
            font.pixelSize: Theme.fontNormal; font.bold: true
            font.family: Theme.fontFamily
            width: parent.width - clearBtn.width
        }
        Text {
            id: clearBtn
            text: NotifState.notifications.length > 0 ? "Clear" : ""
            color: Colors.textMuted; font.pixelSize: Theme.fontSmall
            font.family: Theme.fontFamily
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: NotifState.clearAll() }
        }
    }

    Text {
        visible: NotifState.notifications.length === 0
        width: parent.width; text: "No notifications"
        color: Colors.textMuted; font.pixelSize: Theme.fontNormal
        font.family: Theme.fontFamily
        horizontalAlignment: Text.AlignHCenter; topPadding: 4; bottomPadding: 4
    }

    Repeater {
        model: NotifState.notifications.slice().reverse()
        delegate: Rectangle {
            id: notifCard
            required property var modelData
            width: parent.width; height: nc.implicitHeight + 12; radius: Theme.radiusTiny
            color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, 0.5)
            border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.15); border.width: 1
            Column {
                id: nc
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 7 }
                spacing: 2
                Row {
                    width: parent.width
                    Text { text: modelData.appName; color: Colors.accent; font.pixelSize: Theme.fontSmall; font.bold: true; font.family: Theme.fontFamily; width: parent.width - 14; elide: Text.ElideRight }
                    Text { text: "✕"; color: Colors.textMuted; font.pixelSize: Theme.fontSmall; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: NotifState.dismiss(modelData.id) } }
                }
                Text { text: modelData.summary; color: Colors.text; font.pixelSize: Theme.fontNormal; font.bold: true; font.family: Theme.fontFamily; width: parent.width; wrapMode: Text.WordWrap; visible: text.length > 0 }
                Text { text: modelData.body; color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily; width: parent.width; wrapMode: Text.WordWrap; visible: text.length > 0 }

                Flow {
                    width: parent.width
                    spacing: Theme.spacingSmall
                    visible: (modelData.actions?.length ?? 0) > 0
                    topPadding: Theme.spacingTight

                    Repeater {
                        model: modelData.actions ?? []
                        delegate: Rectangle {
                            id: actionBtn
                            required property var modelData
                            // Hide the FDO "default" action — it's the click-on-notif
                            // activation, not a labeled button.
                            visible: modelData.identifier !== "default"
                            implicitWidth: actionLabel.implicitWidth + 16
                            implicitHeight: actionLabel.implicitHeight + 8
                            radius: Theme.radiusTiny
                            color: actionMa.containsMouse
                                ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.25)
                                : Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.12)
                            border.width: 1
                            border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.3)

                            Behavior on color { ColorAnimation { duration: Theme.durFast } }

                            Text {
                                id: actionLabel
                                anchors.centerIn: parent
                                text: modelData.text || modelData.identifier
                                color: Colors.text
                                font.pixelSize: Theme.fontSmall
                                font.family: Theme.fontFamily
                            }
                            MouseArea {
                                id: actionMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NotifState.invokeAction(notifCard.modelData.id, actionBtn.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
