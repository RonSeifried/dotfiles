import QtQuick
import ".."
import Quickshell

Row {
    spacing: 0
    SystemClock { id: clock; precision: SystemClock.Minutes }
    Text {
        text: Qt.formatDateTime(clock.date, "HH:mm")
        color: Colors.text
        font.pixelSize: Theme.fontMedium; font.bold: true
        font.family: Theme.fontFamily
        font.features: { "tnum": 1 }
    }
}
