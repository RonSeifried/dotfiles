import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"

// One compact now-playing component used by both Control Center and its popup.
GlassSurface {
    id: root
    width: parent ? parent.width : 0
    implicitHeight: MprisState.length > 0 ? 146 : 118
    level: "e1"
    frost: true
    frostAlpha: 0.105
    radius: Theme.radiusLarge

    function fmt(sec) {
        if (!sec || sec < 0 || !isFinite(sec)) return "0:00"
        const s = Math.floor(sec), m = Math.floor(s / 60)
        return m + ":" + String(s % 60).padStart(2, "0")
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingLarge
        spacing: Theme.spacingSmall

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingLarge
            Rectangle {
                Layout.preferredWidth: 72; Layout.preferredHeight: 72
                radius: Theme.radiusMedium; clip: true
                color: Qt.rgba(0, 0, 0, 0.18)
                Image {
                    id: art; anchors.fill: parent; source: MprisState.art
                    fillMode: Image.PreserveAspectCrop; asynchronous: true
                }
                Text {
                    anchors.centerIn: parent; visible: art.status !== Image.Ready
                    text: "󰝚"; color: Colors.textMuted; font.pixelSize: 28; font.family: Theme.fontIcon
                }
            }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                Text {
                    Layout.fillWidth: true; text: MprisState.title || MprisState.identity
                    color: Colors.text; font.pixelSize: Theme.fontMedium; font.bold: true
                    font.family: Theme.fontFamily; elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true; text: MprisState.artist || MprisState.identity
                    color: Colors.textMuted; font.pixelSize: Theme.fontSmall
                    font.family: Theme.fontFamily; elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true; text: MprisState.album || ""
                    visible: text.length > 0; color: Colors.textMuted; font.pixelSize: Theme.fontTiny
                    font.family: Theme.fontFamily; elide: Text.ElideRight
                }
                RowLayout {
                    spacing: Theme.spacingNormal
                    Item { Layout.fillWidth: true }
                    Repeater {
                        model: [
                            { glyph: "󰒮", enabled: !!(MprisState.active && MprisState.active.canGoPrevious), action: () => MprisState.prev() },
                            { glyph: MprisState.isPlaying ? "󰏤" : "󰐊", enabled: true, action: () => MprisState.togglePlay() },
                            { glyph: "󰒭", enabled: !!(MprisState.active && MprisState.active.canGoNext), action: () => MprisState.next() }
                        ]
                        delegate: GlassButton {
                            required property var modelData
                            implicitWidth: 32; implicitHeight: 30
                            icon: modelData.glyph
                            enabled: modelData.enabled
                            onClicked: modelData.action()
                        }
                    }
                    Item { Layout.fillWidth: true }
                }
            }
        }

        Item {
            Layout.fillWidth: true; Layout.preferredHeight: 30
            visible: MprisState.length > 0
            GlassSlider {
                id: seek
                anchors { left: parent.left; right: parent.right; top: parent.top }
                accessibleName: "Playback position"
                value: MprisState.position; max: Math.max(1, MprisState.length)
                active: true
                onMoved: v => MprisState.seek(v)
            }
            Text {
                anchors { left: parent.left; bottom: parent.bottom }
                text: root.fmt(MprisState.position); color: Colors.textMuted
                font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily
            }
            Text {
                anchors { right: parent.right; bottom: parent.bottom }
                text: root.fmt(MprisState.length); color: Colors.textMuted
                font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily
            }
        }
    }
}
