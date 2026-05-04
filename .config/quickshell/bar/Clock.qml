import QtQuick
import ".."
import Quickshell

Row {
    spacing: 0
    SystemClock { id: clock; precision: SystemClock.Minutes }
    Text {
        text: Qt.formatDateTime(clock.date, "HH:mm")
        color: Colors.text
        font.pixelSize: 12; font.bold: true
        font.family: "JetBrainsMono Nerd Font"
    }
}
