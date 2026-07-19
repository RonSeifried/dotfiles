import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import ".."

// macOS lock arrangement: small date line above the large thin clock.
Column {
    id: root
    spacing: LockTheme.spacingNormal

    property var date: new Date()

    // Soft shadow keeps the type legible on bright wallpapers.
    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowBlur: 0.6
        shadowOpacity: 0.35
        shadowVerticalOffset: 2
    }

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        font.family: LockTheme.fontFamily
        font.pointSize: LockTheme.fontDate
        font.weight: Font.Medium
        color: Qt.rgba(1, 1, 1, 0.85)
        text: Qt.locale("en_US").toString(root.date, "dddd, d MMMM")
    }

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        renderType: Text.NativeRendering
        font.family: LockTheme.fontFamily
        font.pointSize: LockTheme.fontClock
        font.weight: Font.Light
        color: Qt.rgba(1, 1, 1, 0.95)
        text: {
            const h = root.date.getHours().toString().padStart(2, '0')
            const m = root.date.getMinutes().toString().padStart(2, '0')
            return `${h}:${m}`
        }
    }

    Timer {
        running: true
        repeat: true
        interval: 1000
        onTriggered: root.date = new Date()
    }
}
