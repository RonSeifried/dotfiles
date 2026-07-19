import QtQuick
import Quickshell
import "../.."
import "../../components"

// One notification card: app name, summary, body, dismiss (✕). Clicking the
// body invokes the notification's default action (open), if any. Uses the
// shared glass material so it matches the Control Center tiles above it.
GlassSurface {
    id: card
    property var entry
    level: "e2"
    frost: true
    radius: Theme.radiusLarge

    readonly property var defaultAction: {
        const a = entry && entry.actions ? entry.actions : []
        return a.find(x => x.identifier === "default") || null
    }
    readonly property var secondaryActions: {
        const a = entry && entry.actions ? entry.actions : []
        return a.filter(x => x.identifier !== "default").slice(0, 3)
    }

    // Relative age ("now" / "5m" / "2h" / "1d") — answers the first question
    // anyone asks a history. Minute precision is enough; ticks keep it honest.
    SystemClock { id: ageClock; precision: SystemClock.Minutes }
    readonly property string age: {
        if (!entry || !entry.timestamp) return ""
        const s = Math.max(0, (ageClock.date.getTime() - entry.timestamp) / 1000)
        if (s < 60) return "now"
        if (s < 3600) return Math.floor(s / 60) + "m"
        if (s < 86400) return Math.floor(s / 3600) + "h"
        return Math.floor(s / 86400) + "d"
    }

    implicitHeight: col.implicitHeight + 16

    // Hover lift (card is a button when it has a default action).
    Rectangle {
        anchors.fill: parent
        radius: card.radius
        color: "white"
        opacity: cardHov.containsMouse && card.defaultAction ? 0.05 : 0.0
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
    }

    Column {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
        spacing: 3

        Row {
            width: parent.width
            Text {
                text: card.entry ? card.entry.appName : ""
                color: Colors.accent
                font.pixelSize: Theme.fontTiny; font.bold: true; font.family: Theme.fontFamily
                width: parent.width - 32 - ageLabel.implicitWidth - Theme.spacingSmall
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: ageLabel
                text: card.age
                color: Colors.textMuted
                font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily
                rightPadding: Theme.spacingSmall
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: NotifState.isAppMuted(card.entry ? card.entry.appName : "") ? "󰂛" : "󰂚"
                color: NotifState.isAppMuted(card.entry ? card.entry.appName : "") ? Colors.accent : Colors.textMuted
                font.pixelSize: Theme.fontSmall; font.family: Theme.fontIcon
                rightPadding: Theme.spacingSmall
                MouseArea {
                    anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                    onClicked: if (card.entry) NotifState.toggleAppMuted(card.entry.appName)
                }
            }
            Text {
                text: "󰅖"; color: Colors.textMuted
                font.pixelSize: Theme.fontSmall; font.family: Theme.fontIcon
                MouseArea {
                    anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor
                    onClicked: if (card.entry) NotifState.dismiss(card.entry.id)
                }
            }
        }
        Text {
            visible: text.length > 0
            text: card.entry ? card.entry.summary : ""; color: Colors.text
            font.pixelSize: Theme.fontSmall; font.bold: true; font.family: Theme.fontFamily
            width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
        }
        Text {
            visible: text.length > 0
            text: card.entry ? card.entry.body : ""
            // Brighter than textMuted so body copy stays legible on the dark glass.
            color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.80)
            font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily
            width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight
        }
        Row {
            visible: card.secondaryActions.length > 0
            width: parent.width; spacing: Theme.spacingSmall
            Repeater {
                model: card.secondaryActions
                delegate: GlassButton {
                    required property var modelData
                    label: modelData.text || modelData.identifier
                    vPadding: 4; hPadding: 9
                    onClicked: NotifState.invokeAction(card.entry.id, modelData)
                }
            }
        }
        Row {
            width: parent.width
            visible: card.entry && !card.entry.notif
            spacing: Theme.spacingSmall
            Text { text: "Saved notification"; color: Colors.textMuted; font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily; width: parent.width - snooze.implicitWidth }
            Text {
                id: snooze; text: "Snooze 1h"; color: Colors.accent; font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: NotifState.snooze(card.entry.id, 60) }
            }
        }
    }

    MouseArea {
        id: cardHov
        anchors.fill: parent
        hoverEnabled: true
        z: -1
        cursorShape: card.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (card.defaultAction) NotifState.invokeAction(card.entry.id, card.defaultAction)
    }
}
