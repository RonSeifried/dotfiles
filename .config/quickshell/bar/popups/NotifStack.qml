import QtQuick
import "../.."

// The notification deck that sits BELOW the Control Center panel (same float
// window). Collapsed: the newest card on top of a peeking stack + a header to
// expand / clear all. Expanded: every card in a column. Each card opens or
// dismisses; clear-all wipes the lot.
Item {
    id: root

    property bool expanded: false
    property real maxExpandedHeight: 310
    readonly property var notifs: NotifState.visibleNotifications.slice().reverse()  // newest first
    readonly property int count: notifs.length
    readonly property var groups: {
        if (!SettingsState.groupNotifications)
            return notifs.map((n, i) => ({ name: (n.appName || "Other") + i, entries: [n] }))
        const byApp = {}, order = []
        for (const n of notifs) {
            const key = n.appName || "Other"
            if (!byApp[key]) { byApp[key] = []; order.push(key) }
            byApp[key].push(n)
        }
        return order.map(name => ({ name: name, entries: byApp[name] }))
    }

    visible: count > 0
    implicitHeight: !visible ? 0 : (expanded ? expandedCol.implicitHeight : collapsed.implicitHeight)
    Behavior on implicitHeight { NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutCubic } }

    // ── Collapsed deck ───────────────────────────────────────────
    Item {
        id: collapsed
        width: parent.width
        visible: !root.expanded && root.count > 0
        readonly property int peekDepth: root.count > 2 ? 8 : root.count > 1 ? 4 : 0
        implicitHeight: header.height + 4 + topCard.implicitHeight + peekDepth

        Row {
            id: header
            width: parent.width; height: 18
            Text {
                text: root.count + (root.count === 1 ? " Notification" : " Notifications")
                color: Colors.text; font.pixelSize: Theme.fontSmall; font.bold: true
                font.family: Theme.fontFamily
                width: parent.width - clearAll.width - expandHint.width - 12
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: expandHint
                visible: root.count > 1
                text: "Expand  󰅀"; color: Colors.accent
                font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily
                anchors.verticalCenter: parent.verticalCenter
                rightPadding: Theme.spacingNormal
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.expanded = true }
            }
            Text {
                id: clearAll
                text: "Clear All"; color: Colors.textMuted
                font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily
                anchors.verticalCenter: parent.verticalCenter
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: NotifState.clearAll() }
            }
        }

        // Peeking layers behind the top card imply a deck. Frost material like
        // the card itself (fainter with depth) — no accent, no dark tint.
        Rectangle {
            visible: root.count > 2
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 16; height: topCard.implicitHeight
            y: header.height + 4 + 8
            radius: Theme.radiusLarge
            color: Qt.rgba(1, 1, 1, 0.06)
            border.color: Qt.rgba(1, 1, 1, 0.10); border.width: 1
        }
        Rectangle {
            visible: root.count > 1
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 8; height: topCard.implicitHeight
            y: header.height + 4 + 4
            radius: Theme.radiusLarge
            color: Qt.rgba(1, 1, 1, 0.10)
            border.color: Qt.rgba(1, 1, 1, 0.12); border.width: 1
        }

        NotifCard {
            id: topCard
            width: parent.width
            y: header.height + 4
            entry: root.notifs.length > 0 ? root.notifs[0] : null
        }
    }

    // ── Expanded list ────────────────────────────────────────────
    Item {
        id: expandedCol
        width: parent.width
        visible: root.expanded
        readonly property real listHeight: Math.min(listContent.implicitHeight, root.maxExpandedHeight - expandedHeader.height - Theme.spacingSmall)
        implicitHeight: expandedHeader.height + Theme.spacingSmall + listHeight

        Row {
            id: expandedHeader
            width: parent.width; height: 18
            Text {
                text: "Notifications"; color: Colors.text
                font.pixelSize: Theme.fontSmall; font.bold: true; font.family: Theme.fontFamily
                width: parent.width - collapseBtn.width - clearBtn.width - 12
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: collapseBtn
                text: "Collapse  󰅃"; color: Colors.accent
                font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily
                anchors.verticalCenter: parent.verticalCenter
                rightPadding: Theme.spacingNormal
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.expanded = false }
            }
            Text {
                id: clearBtn
                text: "Clear All"; color: Colors.textMuted
                font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily
                anchors.verticalCenter: parent.verticalCenter
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: { NotifState.clearAll(); root.expanded = false } }
            }
        }

        Flickable {
            id: notifFlick
            anchors { left: parent.left; right: parent.right; top: expandedHeader.bottom; topMargin: Theme.spacingSmall }
            height: expandedCol.listHeight
            contentWidth: width; contentHeight: listContent.implicitHeight
            clip: true; boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            flickDeceleration: 4500

            Column {
                id: listContent
                width: notifFlick.width
                spacing: Theme.spacingSmall
                Repeater {
                    model: root.groups
                    delegate: Column {
                        id: notifGroup
                        required property var modelData
                        width: listContent.width
                        spacing: Theme.spacingTight
                        Text {
                            visible: notifGroup.modelData.entries.length > 1
                            text: notifGroup.modelData.name + "  ·  " + notifGroup.modelData.entries.length
                            color: Colors.textMuted; font.pixelSize: Theme.fontTiny; font.bold: true
                            font.family: Theme.fontFamily; leftPadding: Theme.spacingSmall
                        }
                        Repeater {
                            model: notifGroup.modelData.entries
                            delegate: NotifCard {
                                required property var modelData
                                width: notifGroup.width
                                entry: modelData
                            }
                        }
                    }
                }
            }

            WheelHandler { target: notifFlick }
        }
    }
}
