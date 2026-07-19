import QtQuick
import "../"
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

// Generic, provider-agnostic result list.
// Model entries: { providerId, icon, iconText, title, subtitle, badge, score, onActivate, keepOpen }
Item {
    id: root

    property var results: []

    signal activated(var result)

    property alias listViewAlias: lv
    property alias currentIndex: lv.currentIndex
    property var selectedResult: null

    function syncSelection() {
        selectedResult = lv.currentIndex >= 0 && lv.currentIndex < results.length
            ? results[lv.currentIndex] : null
    }

    implicitHeight: lv.contentHeight
    implicitWidth: 400

    function activateCurrent() {
        if (lv.currentIndex >= 0 && lv.currentIndex < results.length) {
            const r = results[lv.currentIndex]
            if (r && typeof r.onActivate === "function") r.onActivate()
            root.activated(r)
        }
    }

    onResultsChanged: {
        lv.currentIndex = results.length > 0 ? 0 : -1
        syncSelection()
    }

    ListView {
        id: lv
        anchors.fill: parent
        model: root.results
        spacing: 2
        clip: true
        currentIndex: 0
        onCurrentIndexChanged: root.syncSelection()

        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            width: ListView.view.width
            height: Theme.resultItemHeight
            radius: Theme.radiusMedium
            color: {
                if (lv.currentIndex === row.index)
                    return Qt.rgba(1, 1, 1, 0.14)
                if (hover.containsMouse)
                    return Qt.rgba(1, 1, 1, Theme.hoverBrightness)
                return "transparent"
            }
            Behavior on color { ColorAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }

            RowLayout {
                anchors {
                    left: parent.left; right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: Theme.panelPadding
                    rightMargin: Theme.panelPadding
                }
                spacing: Theme.spacingNormal

                // Icon column — image, glyph, or initial fallback.
                Item {
                    Layout.preferredWidth: Theme.appIconSize
                    Layout.preferredHeight: Theme.appIconSize

                    IconImage {
                        id: img
                        anchors.fill: parent
                        source: row.modelData.icon || ""
                        visible: source !== ""
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !img.visible && (row.modelData.iconText || "") !== ""
                        text: row.modelData.iconText || ""
                        color: Colors.accent
                        font.pixelSize: Theme.fontLarge + 2
                        font.family: Theme.fontFamily
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: !img.visible && (row.modelData.iconText || "") === ""
                        radius: Theme.radiusSmall / 2
                        color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.3)
                        Text {
                            anchors.centerIn: parent
                            text: (row.modelData.title || "?").charAt(0).toUpperCase()
                            color: Colors.accent
                            font.pixelSize: Theme.fontMedium
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                    }
                }

                // Title + subtitle column.
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: row.modelData.title || ""
                        color: Colors.text
                        font.pixelSize: Theme.fontMedium
                        font.family: Theme.fontFamily
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: row.modelData.subtitle || ""
                        visible: text.length > 0
                        color: Colors.textMuted
                        font.pixelSize: Theme.fontSmall
                        font.family: Theme.fontFamily
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                // Provider badge.
                Rectangle {
                    visible: (row.modelData.badge || "") !== ""
                    Layout.preferredHeight: 18
                    Layout.preferredWidth: badgeText.implicitWidth + 12
                    // Chip per design language: accent-tinted fill, no border.
                    radius: Theme.radiusSmall
                    color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.18)

                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: row.modelData.badge || ""
                        color: Colors.accent
                        font.pixelSize: Theme.fontTiny + 1
                        font.family: Theme.fontFamily
                    }
                }
            }

            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    lv.currentIndex = row.index
                    root.activateCurrent()
                }
                onEntered: lv.currentIndex = row.index
            }
        }
    }
}
