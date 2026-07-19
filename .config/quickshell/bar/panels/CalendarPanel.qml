import QtQuick
import "../.."
import "../../components"
import Quickshell
import Quickshell.Io

Column {
    id: root
    spacing: Theme.spacingSmall
    anchors { left: parent?.left; right: parent?.right }
    property var agenda: ({ items: [], hasCalendar: false, hasTasks: false })

    Process {
        id: agendaProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/bar/panels/agenda.py"]
        stdout: StdioCollector { onStreamFinished: { try { root.agenda = JSON.parse(text) } catch (e) {} } }
    }
    Component.onCompleted: agendaProc.running = true

    SystemClock { id: cal; precision: SystemClock.Minutes }

    property int calYear:  cal.date.getFullYear()
    property int calMonth: cal.date.getMonth()
    property int today:    cal.date.getDate()

    // Month header
    Row {
        width: parent.width
        Text {
            text: "◀"
            color: Colors.textMuted; font.pixelSize: Theme.fontNormal; font.family: Theme.fontFamily
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.calMonth === 0) { root.calYear--; root.calMonth = 11 } else root.calMonth-- } }
        }
        Text {
            text: Qt.formatDate(new Date(root.calYear, root.calMonth, 1), "MMMM yyyy")
            color: Colors.text; font.pixelSize: Theme.fontNormal; font.bold: true
            font.family: Theme.fontFamily
            width: parent.width - 24; horizontalAlignment: Text.AlignHCenter
        }
        Text {
            text: "▶"
            color: Colors.textMuted; font.pixelSize: Theme.fontNormal; font.family: Theme.fontFamily
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.calMonth === 11) { root.calYear++; root.calMonth = 0 } else root.calMonth++ } }
        }
    }

    // Day-of-week headers
    Grid {
        columns: 7; spacing: 2; width: parent.width
        Repeater {
            model: ["Mo","Di","Mi","Do","Fr","Sa","So"]
            Text {
                width: (parent.width - 12) / 7; text: modelData
                color: Colors.textMuted; font.pixelSize: Theme.fontTiny; font.bold: true
                font.family: Theme.fontFamily
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    Text {
        visible: root.agenda.items.length > 0
        text: "Up Next"; color: Colors.textMuted; font.pixelSize: Theme.fontTiny; font.bold: true; font.family: Theme.fontFamily
        topPadding: Theme.spacingSmall
    }
    Column {
        width: parent.width; spacing: Theme.spacingTight
        Repeater {
            model: root.agenda.items
            delegate: GlassSurface {
                required property var modelData
                width: parent.width; height: 42; level: "e1"; radius: Theme.radiusMedium
                Row {
                    anchors { fill: parent; margins: Theme.spacingNormal }
                    spacing: Theme.spacingNormal
                    Text { width: 38; text: modelData.time || ""; color: Colors.accent; font.pixelSize: Theme.fontTiny; font.bold: true; font.family: Theme.fontFamily; elide: Text.ElideRight }
                    Column {
                        width: parent.width - 46; anchors.verticalCenter: parent.verticalCenter
                        Text { width: parent.width; text: modelData.title; color: Colors.text; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily; elide: Text.ElideRight }
                        Text { visible: text.length > 0; width: parent.width; text: modelData.detail || ""; color: Colors.textMuted; font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily; elide: Text.ElideRight }
                    }
                }
            }
        }
    }
    Text {
        visible: !root.agenda.hasCalendar && !root.agenda.hasTasks
        width: parent.width; horizontalAlignment: Text.AlignHCenter
        text: "Install khal or Taskwarrior to show your agenda"
        color: Colors.textMuted; font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily
    }

    // Calendar grid
    Grid {
        id: grid
        columns: 7; spacing: 2; width: parent.width

        property int firstDay: {
            const d = new Date(root.calYear, root.calMonth, 1).getDay()
            return d === 0 ? 6 : d - 1  // Monday-first
        }
        property int daysInMonth: new Date(root.calYear, root.calMonth + 1, 0).getDate()

        Repeater {
            model: grid.firstDay + grid.daysInMonth

            Rectangle {
                required property int index
                property int day: index - grid.firstDay + 1
                property bool valid: index >= grid.firstDay
                property bool isToday: valid && day === root.today && root.calMonth === cal.date.getMonth() && root.calYear === cal.date.getFullYear()

                width: (grid.width - 12) / 7; height: width; radius: width / 2
                color: isToday ? Colors.accent : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: parent.valid ? parent.day : ""
                    color: parent.isToday ? Colors.bg : Colors.text
                    font.pixelSize: Theme.fontSmall; font.bold: parent.isToday
                    font.family: Theme.fontFamily
                }
            }
        }
    }
}
