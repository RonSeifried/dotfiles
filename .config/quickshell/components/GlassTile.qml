import QtQuick
import ".."

// Quick-control tile (macOS-style): icon left, label + sub stacked right,
// vertically centered, compact fixed height. `on` flips to the prominent
// (accent) tier. The icon sits in a fixed-size box so the nerd-font glyph's
// tall line box can't inflate the row.
GlassSurface {
    id: root
    interactive: true
    radius: Theme.radiusLarge
    tier: on ? "prominent" : "regular"
    property bool on: false
    property string icon: ""
    property string label: ""
    property string sub: ""
    property int padding: Theme.spacingNormal

    readonly property color _fg: on ? Colors.bg : Colors.text
    readonly property color _fgMuted: on
        ? Qt.rgba(Colors.bg.r, Colors.bg.g, Colors.bg.b, 0.7)
        : Colors.textMuted

    implicitWidth:  Math.max(120, row.implicitWidth + 2 * padding)
    implicitHeight: 56

    Row {
        id: row
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.padding
        spacing: Theme.spacingNormal

        Item {
            width: 28; height: 28
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.centerIn: parent
                text: root.icon
                visible: root.icon.length > 0
                color: root._fg
                font.family: Theme.fontFamily
                font.pixelSize: 18
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            // Constrain to the remaining tile width so long names elide.
            readonly property real avail: root.width - 28 - 2 * root.padding - Theme.spacingNormal
            Text {
                width: parent.avail
                text: root.label
                visible: root.label.length > 0
                color: root._fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontNormal
                font.bold: true
                elide: Text.ElideRight
            }
            Text {
                width: parent.avail
                text: root.sub
                visible: root.sub.length > 0
                color: root._fgMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideRight
            }
        }
    }
}
