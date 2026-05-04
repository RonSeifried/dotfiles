import QtQuick
import "../.."

Column {
    id: root
    spacing: Theme.spacingNormal
    anchors { left: parent?.left; right: parent?.right }

    // Sink name
    Text {
        width: parent.width
        text: AudioState.sinkName
        color: Colors.textMuted
        font.pixelSize: Theme.fontSmall
        font.family: Theme.fontFamily
        elide: Text.ElideRight
    }

    // Volume row
    Row {
        width: parent.width; spacing: Theme.spacingNormal

        Text {
            id: volIcon
            text: !AudioState.sinkReady ? "󰕿" : AudioState.muted ? "󰖁" : AudioState.volume > 0.5 ? "󰕾" : AudioState.volume > 0 ? "󰖀" : "󰕿"
            color: AudioState.muted ? Colors.textMuted : Colors.accent
            font.pixelSize: 16; font.family: Theme.fontFamily
            anchors.verticalCenter: volSlider.verticalCenter
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: AudioState.toggleMute()
            }
        }

        Rectangle {
            id: volSlider
            width: parent.width - volIcon.width - volPct.width - 16
            height: 6; radius: 3
            color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.sliderTrackAlpha)

            Rectangle {
                width: Math.min(1, AudioState.volume) * parent.width
                height: parent.height; radius: parent.radius
                color: AudioState.muted ? Colors.textMuted : Colors.accent
                Behavior on width { NumberAnimation { duration: 80 } }
            }
            // 100% marker
            Rectangle {
                x: parent.width * (1.0 / 1.5); y: -2
                width: 1; height: parent.height + 4
                color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.4)
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.SizeHorCursor
                onPressed: ev => AudioState.setVolume(ev.x / width * 1.5)
                onPositionChanged: ev => { if (pressed) AudioState.setVolume(ev.x / width * 1.5) }
            }
        }

        Text {
            id: volPct
            text: Math.round(AudioState.volume * 100) + "%"
            color: Colors.text; font.pixelSize: Theme.fontNormal; font.bold: true
            font.family: Theme.fontFamily; width: 34
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: volSlider.verticalCenter
        }
    }

    // Divider
    Rectangle {
        width: parent.width; height: 1
        color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.dividerAlpha)
    }

    // Source (mic) name
    Text {
        width: parent.width
        text: AudioState.sourceName
        color: Colors.textMuted; font.pixelSize: Theme.fontSmall
        font.family: Theme.fontFamily
        elide: Text.ElideRight
    }

    // Mic row
    Row {
        width: parent.width; spacing: Theme.spacingNormal

        Text {
            id: micIcon
            text: !AudioState.sourceReady ? "󰍮" : AudioState.micMuted ? "󰍭" : "󰍬"
            color: AudioState.micMuted ? Colors.textMuted : Colors.accent
            font.pixelSize: 16; font.family: Theme.fontFamily
            anchors.verticalCenter: micSlider.verticalCenter
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: AudioState.toggleMicMute()
            }
        }

        Rectangle {
            id: micSlider
            width: parent.width - micIcon.width - micPct.width - 16
            height: 6; radius: 3
            color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.sliderTrackAlpha)
            Rectangle {
                width: Math.min(1, AudioState.micVolume) * parent.width
                height: parent.height; radius: parent.radius
                color: AudioState.micMuted ? Colors.textMuted : Colors.accent
                Behavior on width { NumberAnimation { duration: 80 } }
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.SizeHorCursor
                onPressed: ev => AudioState.setMicVolume(ev.x / width)
                onPositionChanged: ev => { if (pressed) AudioState.setMicVolume(ev.x / width) }
            }
        }

        Text {
            id: micPct
            text: Math.round(AudioState.micVolume * 100) + "%"
            color: Colors.text; font.pixelSize: Theme.fontNormal; font.bold: true
            font.family: Theme.fontFamily; width: 34
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: micSlider.verticalCenter
        }
    }
}
