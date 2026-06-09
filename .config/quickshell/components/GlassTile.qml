import QtQuick
import ".."

// Square-ish tile: glyph + label, tappable. `on` flips to prominent (accent)
// tier. Optional secondary text (sub).
GlassSurface {
    id: root
    interactive: true
    radius: Theme.radiusLarge
    tier: on ? "prominent" : "regular"
    property bool on: false
    property string icon: ""
    property string label: ""
    property string sub: ""
    property int padding: Theme.spacingLarge

    readonly property color _fg: on ? Colors.bg : Colors.text
    readonly property color _fgMuted: on
        ? Qt.rgba(Colors.bg.r, Colors.bg.g, Colors.bg.b, 0.7)
        : Colors.textMuted

    implicitWidth:  Math.max(96, col.implicitWidth + 2 * padding)
    implicitHeight: col.implicitHeight + 2 * padding

    Column {
        id: col
        anchors.left: parent.left; anchors.top: parent.top
        anchors.margins: root.padding
        spacing: Theme.spacingTight
        Text {
            text: root.icon
            visible: root.icon.length > 0
            color: root._fg
            font.family: Theme.fontFamily
            font.pixelSize: 20
        }
        Text {
            text: root.label
            visible: root.label.length > 0
            color: root._fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontNormal
            font.bold: true
        }
        Text {
            text: root.sub
            visible: root.sub.length > 0
            color: root._fgMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideRight
        }
    }
}
