import QtQuick
import "../.."
import "../../components"
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Column {
    id: root
    spacing: Theme.spacingNormal
    anchors { left: parent ? parent.left : undefined; right: parent ? parent.right : undefined }

    property var bat: {
        for (const d of UPower.devices.values) {
            if (d.isLaptopBattery && d.ready) return d
        }
        return UPower.displayDevice && UPower.displayDevice.ready ? UPower.displayDevice : null
    }
    property int pct: Math.round((bat ? bat.percentage : 0) * 100)
    property int st: bat ? bat.state : 0
    property bool charging: st === 1
    property bool full: st === 4

    // ── Charge thresholds (sysfs) ────────────────────────────────
    // Requires system/udev/99-charge-threshold.rules installed for write access.
    // Path derived from UPower nativePath so BAT1/etc work, not just BAT0.
    readonly property string batBase: "/sys/class/power_supply/" + (bat && bat.nativePath ? bat.nativePath : "BAT0")
    readonly property string thresholdEndPath:   batBase + "/charge_control_end_threshold"
    readonly property string thresholdStartPath: batBase + "/charge_control_start_threshold"
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

    GlassSurface {
        width: parent.width; height: batteryHero.implicitHeight + 24
        radius: Theme.radiusLarge
        level: "e1"; frost: true; frostAlpha: 0.105
        Column {
            id: batteryHero
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: Theme.spacingSmall
            Row {
                width: parent.width; spacing: Theme.spacingNormal
                Text {
                    text: root.charging ? "󰂄" : Theme.batteryGlyph(root.pct)
                    color: root.charging ? Colors.accent : root.pct < 20 ? Colors.error : Colors.text
                    font.pixelSize: 24; font.family: Theme.fontIcon
                    anchors.verticalCenter: pctLabel.verticalCenter
                }
                Text {
                    id: pctLabel; text: root.pct + "%"
                    color: root.charging ? Colors.accent : root.pct < 20 ? Colors.error : Colors.text
                    font.pixelSize: 24; font.bold: true; font.family: Theme.fontFamily
                    font.features: { "tnum": 1 }
                }
            }
            Text {
                width: parent.width
                text: {
                    if (root.full) return "Fully charged"
                    const secs = root.charging ? (root.bat ? root.bat.timeToFull : 0) : (root.bat ? root.bat.timeToEmpty : 0)
                    const label = root.charging ? "Charging" : "Discharging"
                    if (secs <= 0) return label
                    const h = Math.floor(secs / 3600), m = Math.floor((secs % 3600) / 60)
                    return label + (h > 0 ? " — " + h + "h " + m + "m" : " — " + m + "m")
                }
                color: Colors.textMuted; font.pixelSize: Theme.fontSmall
                font.family: Theme.fontFamily
            }
            Rectangle {
                width: parent.width; height: 6; radius: 3
                color: Qt.rgba(1, 1, 1, Theme.ink.track)
                Rectangle {
                    width: parent.width * Math.min(1, root.pct / 100.0)
                    height: parent.height; radius: parent.radius
                    color: root.pct < 20 && !root.charging ? Colors.error : Colors.accent
                    Behavior on width { NumberAnimation { duration: Theme.durNormal } }
                }
            }
        }
    }

    Rectangle { width: parent.width; height: 1; color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, Colors.dividerAlpha) }

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
            // Segmented cells: accent fill = active (state), neutral idle,
            // white hover, no borders.
            delegate: GlassSurface {
                id: profBtn
                required property var modelData
                width: (parent.width - 8) / 3; height: 32; radius: Theme.radiusSmall
                property bool active: PowerProfiles.profile === modelData.val
                level: "e1"; frost: true
                frostAlpha: active ? 0.20 : 0.075
                interactive: true
                onClicked: PowerProfiles.profile = profBtn.modelData.val
                Column {
                    anchors.centerIn: parent; spacing: 0
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: profBtn.modelData.icon
                        color: profBtn.active ? Colors.text : Colors.textMuted
                        font.pixelSize: Theme.fontNormal; font.family: Theme.fontIcon
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: profBtn.modelData.label
                        color: profBtn.active ? Colors.text : Colors.textMuted
                        font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily
                    }
                }
            }
        }
    }

    GlassSurface {
        width: parent.width; height: 46; radius: Theme.radiusMedium
        level: "e1"; frost: true; frostAlpha: 0.075
        Row {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
            spacing: Theme.spacingNormal
            Column {
                width: parent.width - autoPerf.width - parent.spacing
                Text { text: "Performance on AC"; color: Colors.text; font.pixelSize: Theme.fontSmall; font.bold: true; font.family: Theme.fontFamily }
                Text {
                    text: PowerPolicy.sourceWatts > 0
                        ? "Suitable source · " + PowerPolicy.sourceWatts.toFixed(0) + " W"
                        : "Requires a 45 W or stronger source"
                    color: Colors.textMuted; font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily
                }
            }
            GlassToggle {
                id: autoPerf; checked: PowerPolicy.autoPerformance
                anchors.verticalCenter: parent.verticalCenter
                accessibleName: "Automatically use performance profile on suitable AC power"
                onToggled: checked => PowerPolicy.setAutoPerformance(checked)
            }
        }
    }

    // ── Charge Threshold ─────────────────────────────────────────
    Rectangle {
        visible: root.thresholdAvailable
        width: parent.width; height: 1
        color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, Colors.dividerAlpha)
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

        // Interactive slider → GlassSlider material (white ink track, white
        // fill + knob), NOT the thin accent line — that read as a different
        // control family than the CC's volume/brightness sliders. Snap +
        // commit-on-release logic stays custom (sysfs writes must not fire
        // per-move).
        Item {
            id: thrSlider
            readonly property int minVal: 50
            readonly property int maxVal: 100
            readonly property int step: 5
            // While dragging, show local value; otherwise reflect actual sysfs value
            property int displayVal: root.thresholdEnd
            width: parent.width - thrLabel.width - thrPct.width - 2 * parent.spacing
            height: 26
            readonly property real frac: (displayVal - minVal) / (maxVal - minVal)
            Rectangle {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                height: 8; radius: 4; color: Qt.rgba(1, 1, 1, Theme.ink.track)
                Rectangle {
                    width: parent.width * thrSlider.frac; height: parent.height
                    radius: parent.radius; color: Colors.accent
                }
            }
            Rectangle {
                width: 16; height: 16; radius: 8
                anchors.verticalCenter: parent.verticalCenter
                x: thrSlider.frac * (thrSlider.width - width)
                color: "white"; border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.12)
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.SizeHorCursor
                function updateAt(px) {
                    const raw = thrSlider.minVal + Math.max(0, Math.min(1, px / width))
                        * (thrSlider.maxVal - thrSlider.minVal)
                    thrSlider.displayVal = Math.round(raw / thrSlider.step) * thrSlider.step
                }
                onPressed: ev => updateAt(ev.x)
                onPositionChanged: ev => { if (pressed) updateAt(ev.x) }
                onReleased: if (thrSlider.displayVal !== root.thresholdEnd)
                    root.setEndThreshold(thrSlider.displayVal)
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
