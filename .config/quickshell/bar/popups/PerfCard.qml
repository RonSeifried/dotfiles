import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
import "../../services/performance"

// A single metric card for PerfPanel. Big value top-left, sub-line below,
// area-filled sparkline at the bottom. Optional secondary sparkline (e.g.
// net Tx overlaid on Rx) using accentAlt color. Frost pane on the panel
// glass, like the CC tiles.
GlassSurface {
    id: card

    property string title: ""
    property string icon: ""
    property string bigValue: ""
    property string subValue: ""
    property color subColor: Colors.textMuted

    property var sparkValues: []
    property var sparkSecondaryValues: null
    property real sparkMax: 1.0
    property bool sparkAutoScale: false

    Layout.preferredHeight: 110
    // Fixed height: GlassSurface's childrenRect implicit sizing would loop
    // against the bottom-anchored sparklines.
    implicitHeight: 110

    frost: true
    frostAlpha: 0.10
    radius: Theme.radiusMedium
    clip: true

    ColumnLayout {
        anchors {
            left: parent.left; right: parent.right; top: parent.top
            margins: Theme.panelPadding
        }
        spacing: Theme.spacingTight

        Row {
            spacing: Theme.spacingSmall
            Text {
                text: card.icon
                color: Colors.accent
                font.pixelSize: Theme.fontMedium
                font.family: Theme.fontIcon
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: card.title
                color: Colors.textMuted
                font.pixelSize: Theme.fontSmall
                font.family: Theme.fontFamily
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingNormal
            Text {
                text: card.bigValue
                color: Colors.text
                font.pixelSize: 22
                font.family: Theme.fontFamily
                font.bold: true
            }
            Item { Layout.fillWidth: true }
            Text {
                text: card.subValue
                color: card.subColor
                font.pixelSize: Theme.fontSmall
                font.family: Theme.fontFamily
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    // Sparkline anchored bottom — secondary draws first (behind primary).
    Sparkline {
        id: secondarySpark
        visible: card.sparkSecondaryValues !== null
        anchors {
            left: parent.left; right: parent.right; bottom: parent.bottom
            leftMargin: Theme.spacingTight; rightMargin: Theme.spacingTight; bottomMargin: 2
        }
        height: 32
        values: card.sparkSecondaryValues || []
        maxValue: card.sparkMax
        autoScale: card.sparkAutoScale
        strokeColor: Colors.accentAlt
        fillColor: Qt.rgba(Colors.accentAlt.r, Colors.accentAlt.g, Colors.accentAlt.b, 0.15)
        strokeWidth: 1.2
    }
    Sparkline {
        id: primarySpark
        anchors {
            left: parent.left; right: parent.right; bottom: parent.bottom
            leftMargin: Theme.spacingTight; rightMargin: Theme.spacingTight; bottomMargin: 2
        }
        height: 32
        values: card.sparkValues
        maxValue: card.sparkMax
        autoScale: card.sparkAutoScale
        strokeColor: Colors.accent
        fillColor: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.25)
        strokeWidth: 1.4
    }
}
