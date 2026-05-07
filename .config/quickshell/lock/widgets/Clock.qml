import QtQuick
import QtQuick.Controls
import ".."

Column {
    id: root
    spacing: LockTheme.spacingNormal

    property var date: new Date()

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        renderType: Text.NativeRendering
        font.family: LockTheme.fontFamily
        font.pointSize: LockTheme.fontClock
        font.weight: Font.Light
        color: LockColors.text
        text: {
            const h = root.date.getHours().toString().padStart(2, '0')
            const m = root.date.getMinutes().toString().padStart(2, '0')
            return `${h}:${m}`
        }
    }

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        font.family: LockTheme.fontFamily
        font.pointSize: LockTheme.fontDate
        color: LockColors.textMuted
        text: Qt.formatDate(root.date, "dddd, d MMMM yyyy", Qt.locale("en_US"))
    }

    Timer {
        running: true
        repeat: true
        interval: 1000
        onTriggered: root.date = new Date()
    }
}
