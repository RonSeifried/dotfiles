import QtQuick
import ".."

// Quick-control tile (macOS-26 Control Center). A bright FROST pane on the
// darker panel, generously rounded. State lives in a CIRCULAR icon badge
// (accent-filled when on), with a bold white label and muted sub beside it.
// The card itself never floods with accent and carries no accent border — it
// stays a calm, light glass pane. That contrast (light tiles on darker panel)
// is what gives the Liquid-Glass look.
//
// Interaction (when `expandable`): tapping the BADGE toggles on/off, tapping
// the rest opens the detail page. Non-expandable tiles toggle anywhere.
GlassSurface {
    id: root
    interactive: true
    frost: true
    radius: Theme.radiusLarge
    level: "e2"
    property bool on: false
    property string icon: ""
    property string label: ""
    property string sub: ""
    property bool expandable: false
    property int padding: Theme.spacingLarge
    signal toggled()
    signal opened()

    accessibleName: label
    accessibleDescription: sub
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.description: sub
    Accessible.checkable: !expandable
    Accessible.checked: on
    activeFocusOnTab: true
    Keys.onReturnPressed: root.toggled()
    Keys.onEnterPressed: root.toggled()
    Keys.onSpacePressed: root.toggled()

    implicitWidth:  Math.max(140, row.implicitWidth + 2 * padding + (expandable ? 14 : 0))
    implicitHeight: 64

    // The whole tile toggles; the explicit trailing disclosure opens details.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    Row {
        id: row
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.padding
        spacing: Theme.spacingNormal + 2

        // Circular icon badge — the toggle target.
        Rectangle {
            id: badge
            width: 40; height: 40; radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: root.on ? Colors.accent : Qt.rgba(1, 1, 1, Theme.ink.idle)
            Behavior on color { ColorAnimation { duration: Theme.durNormal } }
            scale: badgeArea.pressed ? 0.90 : 1.0
            Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }

            Text {
                anchors.centerIn: parent
                text: root.icon
                visible: root.icon.length > 0
                color: root.on ? Colors.bg : Colors.text
                Behavior on color { ColorAnimation { duration: Theme.durNormal } }
                font.family: Theme.fontIcon
                font.pixelSize: 19
            }
            Rectangle {
                anchors.fill: parent; radius: parent.radius; color: "white"
                opacity: badgeArea.containsMouse ? Theme.hoverBrightness : 0.0
                Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
            }
            MouseArea {
                id: badgeArea
                anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggled()
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            readonly property real avail: root.width - 40 - 2 * root.padding
                - (Theme.spacingNormal + 2) - (root.expandable ? 14 : 0)
            Text {
                width: parent.avail
                text: root.label
                visible: root.label.length > 0
                color: Colors.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontMedium
                font.bold: true
                elide: Text.ElideRight
            }
            Text {
                width: parent.avail
                text: root.sub
                visible: root.sub.length > 0
                color: Colors.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideRight
            }
        }
    }

    // Explicit disclosure target makes the split action discoverable: the
    // tile toggles state while this button opens details.
    Rectangle {
        visible: root.expandable
        width: 28; height: 28; radius: Theme.radiusSmall
        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: Theme.spacingNormal }
        color: disclosureHover.hovered ? Qt.rgba(1, 1, 1, Theme.hoverBrightness) : "transparent"
        Text {
            anchors.centerIn: parent
            text: "󰅂"; color: Colors.textMuted
            font.pixelSize: Theme.fontMedium; font.family: Theme.fontIcon
        }
        HoverHandler { id: disclosureHover }
        TapHandler { onTapped: root.opened() }
    }
}
