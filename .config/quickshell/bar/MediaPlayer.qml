import QtQuick
import QtQuick.Layouts
import ".."

Item {
    id: root

    // Owning bar PanelWindow — used so label-click pins the popup to the
    // correct screen (multi-monitor: each bar has its own pill instance).
    property var bar
    // Exposed so the popup's close-timer knows when the pointer left the label.
    readonly property alias labelHovered: labelHover.hovered

    implicitHeight: row.implicitHeight
    implicitWidth: row.implicitWidth

    RowLayout {
        id: row
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: Theme.spacingSmall

        // Transport — uniform glyph size so baselines align.
        Text {
            text: "󰒮"
            color: MprisState.active?.canGoPrevious ? Colors.text : Colors.textMuted
            font.pixelSize: Theme.fontLarge; font.family: Theme.fontIcon
            Layout.alignment: Qt.AlignVCenter
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: MprisState.prev()
            }
        }

        Text {
            text: MprisState.isPlaying ? "󰏤" : "󰐊"
            color: Colors.accent
            font.pixelSize: Theme.fontLarge; font.family: Theme.fontIcon
            Layout.alignment: Qt.AlignVCenter
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: MprisState.togglePlay()
            }
        }

        Text {
            text: "󰒭"
            color: MprisState.active?.canGoNext ? Colors.text : Colors.textMuted
            font.pixelSize: Theme.fontLarge; font.family: Theme.fontIcon
            Layout.alignment: Qt.AlignVCenter
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: MprisState.next()
            }
        }

        // Track label + multi-player count. Hover/click here opens MPRIS panel.
        // Sized off intrinsic text width (no fillWidth) so the outer pill
        // hugs the content — fillWidth would zero-collapse with no fixed parent.
        Item {
            id: labelArea
            readonly property int maxWidth: 280
            readonly property int textNatural: trackLabel.implicitWidth + (countBadge.visible ? countBadge.implicitWidth + Theme.spacingTight : 0)

            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Math.min(textNatural, maxWidth)
            implicitHeight: trackLabel.implicitHeight
            clip: true

            Text {
                id: trackLabel
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                width: Math.min(implicitWidth,
                    labelArea.width - (countBadge.visible ? countBadge.width + Theme.spacingTight : 0))
                text: {
                    const a = MprisState.artist
                    const t = MprisState.title
                    if (a && t) return a + " — " + t
                    return t || a || MprisState.identity || ""
                }
                color: Colors.text
                font.pixelSize: Theme.fontMedium
                font.family: Theme.fontFamily
                font.bold: MprisState.isPlaying
                elide: Text.ElideRight
            }

            Text {
                id: countBadge
                visible: MprisState.players.length > 1
                anchors { left: trackLabel.right; leftMargin: Theme.spacingTight; verticalCenter: trackLabel.verticalCenter }
                text: "·" + MprisState.players.length
                color: Colors.textMuted
                font.pixelSize: Theme.fontTiny
                font.family: Theme.fontFamily
            }

            // Small open-delay so brushing past the label en route to the
            // status cluster doesn't flash the panel (close grace is 220ms).
            Timer {
                id: hoverOpenDelay
                interval: 150
                onTriggered: {
                    if (!labelHover.hovered || !root.bar) return
                    ControlState.activeScreen = root.bar.screen.name
                    ControlState.rightPanel = "mpris"
                }
            }
            HoverHandler {
                id: labelHover
                onHoveredChanged: hovered ? hoverOpenDelay.restart() : hoverOpenDelay.stop()
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!root.bar) return
                    if (root.bar.pinnedPanel === "mpris") {
                        root.bar.pinnedPanel = ""
                        ControlState.rightPanel = "none"
                    } else {
                        ControlState.activeScreen = root.bar.screen.name
                        ControlState.rightPanel = "mpris"
                        root.bar.pinnedPanel = "mpris"
                    }
                }
            }
        }
    }
}
