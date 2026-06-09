import QtQuick
import ".."

// Grouped-content container. A non-interactive e2 surface with standard
// padding; children laid out by the consumer.
GlassSurface {
    id: root
    tier: "regular"
    radius: Theme.radiusLarge
    property int padding: Theme.panelPadding
    default property alias cardContent: holder.data

    implicitWidth:  holder.implicitWidth  + 2 * padding
    implicitHeight: holder.implicitHeight + 2 * padding

    Item {
        id: holder
        anchors.fill: parent
        anchors.margins: root.padding
    }
}
