import QtQuick
import "../.."
import Quickshell
import Quickshell.Io
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

    // ── Charge thresholds (sysfs) ────────────────────────────────
    // Requires system/udev/99-charge-threshold.rules installed for write access.
    readonly property string thresholdEndPath:   "/sys/class/power_supply/BAT0/charge_control_end_threshold"
    readonly property string thresholdStartPath: "/sys/class/power_supply/BAT0/charge_control_start_threshold"
    property int thresholdEnd:   80
    property int thresholdStart: 75
    property bool thresholdAvailable: false

    FileView {
        id: endFile
        path: root.thresholdEndPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const v = parseInt(text().trim(), 10)
            if (!isNaN(v)) { root.thresholdEnd = v; root.thresholdAvailable = true }
        }
        onLoadFailed: root.thresholdAvailable = false
    }
    FileView {
        id: startFile
        path: root.thresholdStartPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const v = parseInt(text().trim(), 10)
            if (!isNaN(v)) root.thresholdStart = v
        }
    }

    Process {
        id: thresholdWriter
        stdout: StdioCollector { id: thresholdOut }
        stderr: StdioCollector { id: thresholdErr }
        onExited: (code) => {
            if (code !== 0) {
                root.lastError = thresholdErr.text.trim() || ("exit " + code)
                endFile.reload()
                startFile.reload()
            } else {
                root.lastError = ""
            }
        }
    }
    Process { id: persistWriter }

    property string lastError: ""

    // Hysteresis between start and end (driver requires end >= start + delta).
    readonly property int thresholdHysteresis: 5
    readonly property string statePath: Quickshell.env("HOME") + "/.local/state/quickshell/battery-threshold"

    function setEndThreshold(value) {
        const newEnd = value
        // end=100 means "no limit" → start=0 so laptop keeps charging fully (no bypass-band).
        // Below 100: keep hysteresis so battery doesn't constantly micro-charge.
        const newStart = newEnd >= 100 ? 0 : Math.max(0, newEnd - root.thresholdHysteresis)
        const curEnd = root.thresholdEnd
        // Order matters: driver rejects writes that would make start > end.
        // If new_start would exceed current end, raise end first; otherwise lower start first.
        const main = newStart > curEnd
            ? "echo " + newEnd + " > " + root.thresholdEndPath
              + " && echo " + newStart + " > " + root.thresholdStartPath
            : "echo " + newStart + " > " + root.thresholdStartPath
              + " && echo " + newEnd + " > " + root.thresholdEndPath
        // Force state-machine re-eval: driver may stay in "stopped" state if bat is between
        // start and end and was previously paused. Bump start above end-1 then back to target
        // — the second write kicks the driver into re-evaluating bat vs thresholds.
        const kickHigh = Math.max(0, newEnd - 1)
        const kick = "echo " + kickHigh + " > " + root.thresholdStartPath
                   + " && echo " + newStart + " > " + root.thresholdStartPath
        thresholdWriter.command = ["sh", "-c", main + " && " + kick]
        thresholdWriter.running = true
        // Persist for reboot restore (systemd user service reapplies on boot).
        persistWriter.command = ["sh", "-c",
            "mkdir -p \"$(dirname '" + root.statePath + "')\" && echo " + newEnd + " > '" + root.statePath + "'"]
        persistWriter.running = true
    }

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

    // ── Charge Threshold ─────────────────────────────────────────
    Rectangle {
        visible: root.thresholdAvailable
        width: parent.width; height: 1
        color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.dividerAlpha)
    }

    Text {
        visible: root.thresholdAvailable
        text: "Charge Threshold"
        color: Colors.textMuted; font.pixelSize: Theme.fontSmall; font.bold: true
        font.family: Theme.fontFamily
    }

    // Slider row: live drag preview + commit on release
    Row {
        visible: root.thresholdAvailable
        width: parent.width; spacing: Theme.spacingNormal

        Text {
            id: thrLabel
            text: "Stop at"
            color: Colors.textMuted; font.pixelSize: Theme.fontSmall
            font.family: Theme.fontFamily
            anchors.verticalCenter: thrSlider.verticalCenter
        }

        Rectangle {
            id: thrSlider
            readonly property int minVal: 50
            readonly property int maxVal: 100
            readonly property int step: 5
            // While dragging, show local value; otherwise reflect actual sysfs value
            property int displayVal: root.thresholdEnd

            width: parent.width - thrLabel.width - thrPct.width - 2 * parent.spacing
            height: 6; radius: 3
            color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.sliderTrackAlpha)

            Rectangle {
                width: parent.width * Math.max(0, (thrSlider.displayVal - thrSlider.minVal)) / (thrSlider.maxVal - thrSlider.minVal)
                height: parent.height; radius: parent.radius
                color: thrSlider.displayVal >= 100 ? Colors.error : Colors.accent
                Behavior on width { NumberAnimation { duration: 80 } }
            }
            // 80% recommended marker
            Rectangle {
                x: parent.width * (80 - thrSlider.minVal) / (thrSlider.maxVal - thrSlider.minVal); y: -2
                width: 1; height: parent.height + 4
                color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.4)
            }

            function snap(x) {
                const raw = thrSlider.minVal + (x / width) * (thrSlider.maxVal - thrSlider.minVal)
                return Math.max(thrSlider.minVal, Math.min(thrSlider.maxVal,
                    Math.round(raw / thrSlider.step) * thrSlider.step))
            }

            MouseArea {
                anchors.fill: parent; cursorShape: Qt.SizeHorCursor
                onPressed: ev => thrSlider.displayVal = thrSlider.snap(ev.x)
                onPositionChanged: ev => { if (pressed) thrSlider.displayVal = thrSlider.snap(ev.x) }
                onReleased: {
                    if (thrSlider.displayVal !== root.thresholdEnd)
                        root.setEndThreshold(thrSlider.displayVal)
                }
            }

            // Sync local preview when sysfs reports new value (and we're not dragging)
            Connections {
                target: root
                function onThresholdEndChanged() { thrSlider.displayVal = root.thresholdEnd }
                function onLastErrorChanged() {
                    if (root.lastError !== "") thrSlider.displayVal = root.thresholdEnd
                }
            }
        }

        Text {
            id: thrPct
            text: thrSlider.displayVal + "%"
            color: Colors.text; font.pixelSize: Theme.fontNormal; font.bold: true
            font.family: Theme.fontFamily; width: 38
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: thrSlider.verticalCenter
        }
    }

    Text {
        visible: root.thresholdAvailable && root.lastError !== ""
        width: parent.width
        text: "Write failed: " + root.lastError
        color: Colors.error; font.pixelSize: Theme.fontTiny
        font.family: Theme.fontFamily; wrapMode: Text.WordWrap
    }
}
