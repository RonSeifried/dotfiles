import QtQuick
import ".."

// Action button. Icon and/or text. tier "prominent" = accent-tinted primary.
GlassSurface {
    id: root
    interactive: true
    radius: Theme.radiusPill
    property string icon: ""      // nerd-font glyph
    property string label: ""
    property int hPadding: Theme.spacingLarge
    property int vPadding: Theme.spacingSmall

    readonly property color _fg: tier === "prominent" ? Colors.bg : Colors.text

    implicitWidth:  row.implicitWidth  + 2 * hPadding
    implicitHeight: row.implicitHeight + 2 * vPadding

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.spacingSmall
        Text {
            visible: root.icon.length > 0
            text: root.icon
            color: root._fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontMedium
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            visible: root.label.length > 0
            text: root.label
            color: root._fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontNormal
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
