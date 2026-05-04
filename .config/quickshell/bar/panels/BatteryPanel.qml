import QtQuick
import "../.."
import Quickshell.Services.UPower

Column {
    id: root
    spacing: Theme.spacingNormal
    anchors { left: parent?.left; right: parent?.right }

    property var bat: {
        for (const d of UPower.devices.values) {
            if (d.isLaptopBattery && d.ready) return d
        }
        return UPower.displayDevice?.ready ? UPower.displayDevice : null
    }
    property int pct: Math.round((bat?.percentage ?? 0) * 100)
    property int st: bat?.state ?? 0
    property bool charging: st === 1
    property bool full: st === 4

    // Big % + icon
    Row {
        width: parent.width; spacing: Theme.spacingNormal
        Text {
            text: root.full ? "󰁹" : root.charging ? "󰂋" : root.pct < 25 ? "󰁻" : "󰁽"
            color: root.charging ? Colors.success : root.pct < 20 ? Colors.error : Colors.text
            font.pixelSize: 24; font.family: Theme.fontFamily
            anchors.verticalCenter: pctLabel.verticalCenter
        }
        Text {
            id: pctLabel
            text: root.pct + "%"
            color: root.charging ? Colors.success : root.pct < 20 ? Colors.error : Colors.text
            font.pixelSize: 24; font.bold: true; font.family: Theme.fontFamily
        }
    }

    // Status text
    Text {
        width: parent.width
        text: {
            if (root.full) return "Fully charged"
            const secs = root.charging ? (root.bat?.timeToFull ?? 0) : (root.bat?.timeToEmpty ?? 0)
            const label = root.charging ? "Charging" : "Discharging"
            if (secs <= 0) return label
            const h = Math.floor(secs / 3600)
            const m = Math.floor((secs % 3600) / 60)
            return label + (h > 0 ? " — " + h + "h " + m + "m" : " — " + m + "m")
        }
        color: Colors.textMuted; font.pixelSize: Theme.fontSmall
        font.family: Theme.fontFamily; wrapMode: Text.WordWrap
    }

    // Battery bar
    Rectangle {
        width: parent.width; height: 5; radius: 3
        color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.sliderTrackAlpha)
        Rectangle {
            width: parent.width * Math.min(1, root.pct / 100.0)
            height: parent.height; radius: parent.radius
            color: root.charging ? Colors.success : root.pct < 20 ? Colors.error : Colors.accent
            Behavior on width { NumberAnimation { duration: 400 } }
        }
    }

    Rectangle { width: parent.width; height: 1; color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.dividerAlpha) }

    // Power profiles
    Text {
        text: "Power Profile"
        color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.bold: true
        font.family: Theme.fontFamily
    }

    Row {
        width: parent.width; spacing: Theme.spacingTight

        Repeater {
            model: [
                { label: "Saver",    icon: "󰂮", val: 0 },
                { label: "Balanced", icon: "󰁹", val: 1 },
                { label: "Perf",     icon: "󰓅", val: 2 }
            ]
            delegate: Rectangle {
                id: profBtn
                required property var modelData
                width: (parent.width - 8) / 3; height: 32; radius: Theme.radiusTiny
                property bool active: PowerProfiles.profile === modelData.val
                color: active
                    ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.4)
                    : hovArea.containsMouse
                        ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.15)
                        : Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, 0.4)
                border.color: active ? Colors.accent : Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.2)
                border.width: 1
                Column {
                    anchors.centerIn: parent; spacing: 0
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: profBtn.modelData.icon
                        color: profBtn.active ? Colors.text : Colors.textMuted
                        font.pixelSize: Theme.fontNormal; font.family: Theme.fontFamily
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: profBtn.modelData.label
                        color: profBtn.active ? Colors.text : Colors.textMuted
                        font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily
                    }
                }
                MouseArea { id: hovArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: PowerProfiles.profile = profBtn.modelData.val }
            }
        }
    }
}
