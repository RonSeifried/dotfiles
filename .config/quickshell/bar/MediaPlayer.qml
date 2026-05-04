import QtQuick
import QtQuick.Layouts
import ".."

Item {
    id: root

    implicitHeight: row.implicitHeight
    implicitWidth: row.implicitWidth

    RowLayout {
        id: row
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: Theme.spacingSmall

        // Prev
        Text {
            text: "󰒮"
            color: MprisState.active?.canGoPrevious ? Colors.text : Colors.textMuted
            font.pixelSize: Theme.fontMedium; font.family: Theme.fontFamily
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: MprisState.prev()
            }
        }

        // Play/Pause
        Text {
            text: MprisState.isPlaying ? "󰏤" : "󰐊"
            color: Colors.accent
            font.pixelSize: Theme.fontLarge; font.family: Theme.fontFamily
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: MprisState.togglePlay()
            }
        }

        // Next
        Text {
            text: "󰒭"
            color: MprisState.active?.canGoNext ? Colors.text : Colors.textMuted
            font.pixelSize: Theme.fontMedium; font.family: Theme.fontFamily
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: MprisState.next()
            }
        }

        // Track label (artist — title)
        Item {
            Layout.fillWidth: true
            Layout.maximumWidth: 260
            implicitWidth: Math.min(trackLabel.implicitWidth, 260)
            implicitHeight: trackLabel.implicitHeight
            clip: true

            Text {
                id: trackLabel
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const a = MprisState.artist
                    const t = MprisState.title
                    if (a && t) return a + " — " + t
                    return t || a || ""
                }
                color: Colors.text
                font.pixelSize: Theme.fontMedium
                font.family: Theme.fontFamily
                font.bold: MprisState.isPlaying
                elide: Text.ElideRight
                width: parent.width
            }
        }
    }
}
