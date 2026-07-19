import QtQuick
import QtQuick.Controls
import Quickshell.Services.UPower
import ".."

Rectangle {
    id: root

    property var bat: {
        for (const d of UPower.devices.values) {
            if (d.isLaptopBattery && d.ready) return d
        }
        return UPower.displayDevice?.ready ? UPower.displayDevice : null
    }
    property int pct: Math.round((bat?.percentage ?? 0) * 100)
    property int st: bat?.state ?? 0
    property bool charging: st === 1

    visible: bat !== null && (bat?.isPresent ?? false)

    width: pillRow.implicitWidth + 24
    height: LockTheme.batteryPillHeight
    radius: LockTheme.radiusPill
    // Frost chip (mirrors GlassSurface.frost, lighter pill variant)
    color: Qt.rgba(1, 1, 1, LockTheme.frostPillFillAlpha)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, LockTheme.frostBorderAlpha)

    function iconForPct(p, isCharging) {
        if (isCharging) return "󰂄"
        if (p >= 90) return "󰂂"
        if (p >= 80) return "󰂁"
        if (p >= 70) return "󰂀"
        if (p >= 60) return "󰁿"
        if (p >= 50) return "󰁾"
        if (p >= 40) return "󰁽"
        if (p >= 30) return "󰁼"
        if (p >= 20) return "󰁻"
        if (p >= 10) return "󰁺"
        return "󰂎"
    }

    Row {
        id: pillRow
        anchors.centerIn: parent
        spacing: 6

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.iconForPct(root.pct, root.charging)
            color: root.charging
                ? LockColors.accentAlt
                : (root.pct <= 20 ? LockColors.error : LockColors.text)
            font.family: LockTheme.fontIcon
            font.pointSize: LockTheme.fontPercent + 2
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.pct + "%"
            color: LockColors.text
            font.family: LockTheme.fontFamily
            font.pointSize: LockTheme.fontPercent
        }
    }
}
