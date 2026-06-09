import QtQuick
import QtQuick.Layouts
import "../.."

Column {
    id: root
    spacing: Theme.spacingNormal
    anchors { left: parent?.left; right: parent?.right }

    function _fmt(sec) {
        if (!sec || sec < 0 || !isFinite(sec)) return "0:00"
        const s = Math.floor(sec)
        const m = Math.floor(s / 60)
        const r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }

    // ── Cover ────────────────────────────────────────────────────
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 180; height: 180

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusMedium
            color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, 0.85)
            border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.dividerAlpha)
            border.width: 1
            clip: true

            Image {
                id: coverImg
                anchors.fill: parent
                source: MprisState.art
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: source != "" && status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                visible: !coverImg.visible
                text: "󰝚"
                color: Colors.textMuted
                font.pixelSize: 64
                font.family: Theme.fontFamily
            }
        }
    }

    // ── Text block ───────────────────────────────────────────────
    Column {
        width: parent.width
        spacing: 2

        Text {
            width: parent.width
            text: MprisState.artist
            color: Colors.textMuted
            font.pixelSize: Theme.fontSmall
            font.family: Theme.fontFamily
            elide: Text.ElideRight
            visible: text.length > 0
        }
        Text {
            width: parent.width
            text: MprisState.title || MprisState.identity
            color: Colors.text
            font.pixelSize: Theme.fontMedium
            font.family: Theme.fontFamily
            font.bold: true
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: MprisState.album
            color: Colors.textMuted
            font.pixelSize: Theme.fontTiny
            font.family: Theme.fontFamily
            elide: Text.ElideRight
            visible: text.length > 0
        }
    }

    // ── Progress bar ─────────────────────────────────────────────
    Item {
        width: parent.width
        height: progressTrack.height + timeRow.height + 4
        visible: MprisState.length > 0

        Rectangle {
            id: progressTrack
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 4; radius: 2
            color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.sliderTrackAlpha)

            readonly property real ratio: MprisState.length > 0
                ? Math.min(1, Math.max(0, MprisState.position / MprisState.length))
                : 0

            Rectangle {
                width: progressTrack.ratio * parent.width
                height: parent.height; radius: parent.radius
                color: Colors.accent
                Behavior on width { NumberAnimation { duration: 120 } }
            }

            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -6; anchors.bottomMargin: -6
                cursorShape: MprisState.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: MprisState.canSeek && MprisState.length > 0
                onPressed: ev => MprisState.seek(ev.x / width * MprisState.length)
                onPositionChanged: ev => {
                    if (pressed) MprisState.seek(Math.max(0, Math.min(width, ev.x)) / width * MprisState.length)
                }
            }
        }

        RowLayout {
            id: timeRow
            anchors { left: parent.left; right: parent.right; top: progressTrack.bottom; topMargin: 4 }
            Text {
                text: root._fmt(MprisState.position)
                color: Colors.textMuted; font.pixelSize: Theme.fontTiny
                font.family: Theme.fontFamily
            }
            Item { Layout.fillWidth: true }
            Text {
                text: root._fmt(MprisState.length)
                color: Colors.textMuted; font.pixelSize: Theme.fontTiny
                font.family: Theme.fontFamily
            }
        }
    }

    // ── Transport (uniform glyph size for aligned baselines) ─────
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spacingLarge
        topPadding: 4
        bottomPadding: 2

        readonly property int btnSize: 24

        Text {
            text: "󰒮"
            color: MprisState.active?.canGoPrevious ? Colors.text : Colors.textMuted
            font.pixelSize: parent.btnSize; font.family: Theme.fontFamily
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: MprisState.prev()
            }
        }
        Text {
            text: MprisState.isPlaying ? "󰏤" : "󰐊"
            color: Colors.accent
            font.pixelSize: parent.btnSize; font.family: Theme.fontFamily
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: MprisState.togglePlay()
            }
        }
        Text {
            text: "󰒭"
            color: MprisState.active?.canGoNext ? Colors.text : Colors.textMuted
            font.pixelSize: parent.btnSize; font.family: Theme.fontFamily
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: MprisState.next()
            }
        }
    }

    // ── Player tabs (only when multiple) — bottom, centered ──────
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spacingTight
        visible: MprisState.players.length > 1
        topPadding: 2

        Repeater {
            model: MprisState.players
            delegate: Rectangle {
                required property var modelData
                required property int index

                readonly property bool isActive: MprisState.active === modelData
                implicitHeight: 22
                implicitWidth: tabLabel.implicitWidth + 14
                radius: Theme.radiusTiny
                color: isActive
                    ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.22)
                    : Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, 0.55)
                border.color: isActive
                    ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Theme.elevation.e1BorderAlpha)
                    : Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.dividerAlpha)
                border.width: 1

                Text {
                    id: tabLabel
                    anchors.centerIn: parent
                    text: modelData.identity ?? "player"
                    color: parent.isActive ? Colors.text : Colors.textMuted
                    font.pixelSize: Theme.fontTiny
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                }

                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: MprisState.selectAt(index)
                }
            }
        }
    }
}
