import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import ".."
import "../components"

GlassSurface {
    id: root
    property var result: null
    level: "e1"
    radius: Theme.radiusLarge

    readonly property string suffix: result && result.path
        ? result.path.split(".").pop().toLowerCase() : ""
    readonly property bool isImage: ["png", "jpg", "jpeg", "webp", "gif", "bmp", "svg", "avif"].indexOf(suffix) >= 0

    Process { id: actionProc }
    function run(args) { actionProc.command = args; actionProc.running = true }
    function openResult() { if (result && result.path) run(["xdg-open", result.path]) }
    function reveal() { if (result && result.path) run(["nautilus", "--select", result.path]) }
    function copyPath() {
        if (result && result.path) run(["sh", "-c", "printf %s \"$1\" | wl-copy", "_", result.path])
    }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: Theme.spacingLarge
        spacing: Theme.spacingNormal
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 120
            visible: root.isImage

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusMedium
                color: Qt.rgba(0, 0, 0, 0.18)
                clip: true
                Image {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingTight
                    source: root.isImage && root.result && root.result.path
                        ? "file://" + encodeURI(root.result.path) : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                    sourceSize.width: 420
                    sourceSize.height: 420
                }
            }
        }
        Item { Layout.fillHeight: true; visible: !root.isImage }
        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: !root.isImage
            text: result ? (result.iconText || "") : ""
            color: Colors.accent; font.pixelSize: 36; font.family: Theme.fontIcon
        }
        Text {
            Layout.fillWidth: true
            text: result ? (result.title || "") : ""
            color: Colors.text; font.pixelSize: Theme.fontMedium; font.bold: true
            font.family: Theme.fontFamily; horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
        }
        Text {
            Layout.fillWidth: true
            text: result ? (result.path || result.subtitle || "") : ""
            color: Colors.textMuted; font.pixelSize: Theme.fontTiny
            font.family: Theme.fontFamily; horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideMiddle
        }
        Item { Layout.fillHeight: true; visible: !root.isImage }
        RowLayout {
            Layout.fillWidth: true; spacing: Theme.spacingSmall
            Layout.minimumHeight: 32
            GlassButton { Layout.fillWidth: true; label: "Open"; onClicked: root.openResult() }
            GlassButton { Layout.fillWidth: true; label: "Reveal"; onClicked: root.reveal() }
        }
        GlassButton { Layout.fillWidth: true; Layout.minimumHeight: 32; label: "Copy Path"; onClicked: root.copyPath() }
    }
}
