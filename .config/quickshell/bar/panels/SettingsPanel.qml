import QtQuick
import Quickshell
import Quickshell.Io
import "../.."
import "../../components"

// The most useful preferences live where users already expect system settings:
// inside Control Center.  This is intentionally compact, not a second control
// center made out of settings.
Column {
    id: root
    width: parent ? parent.width : 340
    spacing: Theme.spacingNormal
    property var health: ({ errors: 0, warnings: 0, issues: [] })

    Process {
        id: doctor
        command: [Quickshell.env("HOME") + "/.config/scripts/dotfiles-doctor.sh", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.health = JSON.parse(text) } catch (e) { root.health = ({ errors: 1, warnings: 0, issues: ["Health check failed"] }) }
            }
        }
    }
    Process { id: actionProc }
    Component.onCompleted: doctor.running = true

    component SettingToggle: GlassSurface {
        id: row
        property string label: ""
        property string description: ""
        property bool checked: false
        signal changed(bool value)
        width: parent ? parent.width : 340
        height: 50
        level: "e1"; radius: Theme.radiusMedium
        Row {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Theme.spacingLarge }
            Column {
                width: parent.width - toggle.width - Theme.spacingNormal
                spacing: 1
                Text { text: row.label; color: Colors.text; font.pixelSize: Theme.fontSmall; font.bold: true; font.family: Theme.fontFamily }
                Text { width: parent.width; text: row.description; color: Colors.textMuted; elide: Text.ElideRight; font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily }
            }
            GlassToggle { id: toggle; checked: row.checked; accessibleName: row.label; onToggled: v => row.changed(v) }
        }
    }

    Text { text: "Appearance"; color: Colors.textMuted; font.pixelSize: Theme.fontTiny; font.bold: true; font.family: Theme.fontFamily }
    SettingToggle {
        label: "Adaptive glass"; description: "Increase density on bright or detailed wallpapers"
        checked: SettingsState.adaptiveMaterial
        onChanged: v => { SettingsState.adaptiveMaterial = v; SettingsState.save() }
    }
    SettingToggle {
        label: "Reduced motion"; description: "Use fades and shorter travel"
        checked: SettingsState.motion !== "normal"
        onChanged: v => { SettingsState.motion = v ? "reduced" : "normal"; SettingsState.save() }
    }
    SettingToggle {
        label: "Media in menu bar"; description: "Show the active player beside the window title"
        checked: SettingsState.showMediaInBar
        onChanged: v => { SettingsState.showMediaInBar = v; SettingsState.save() }
    }
    SettingToggle {
        label: "System tray"; description: "Show application status icons"
        checked: SettingsState.showTray
        onChanged: v => { SettingsState.showTray = v; SettingsState.save() }
    }
    SettingToggle {
        label: "Performance pill"; description: "Show live CPU history in the menu bar"
        checked: ControlState.perfPillVisible
        onChanged: v => { ControlState.perfPillVisible = v; SettingsState.showPerformancePill = v; SettingsState.save() }
    }

    Text { text: "Search"; color: Colors.textMuted; font.pixelSize: Theme.fontTiny; font.bold: true; font.family: Theme.fontFamily }
    SettingToggle {
        label: "Files in Spotlight"; description: "Search the local content index"
        checked: SettingsState.searchFiles
        onChanged: v => { SettingsState.searchFiles = v; SettingsState.save() }
    }
    SettingToggle {
        label: "Web fallback"; description: "Offer a web search after local results"
        checked: SettingsState.searchWeb
        onChanged: v => { SettingsState.searchWeb = v; SettingsState.save() }
    }
    SettingToggle {
        label: "AI provider"; description: "Keep the optional AI search mode available"
        checked: SettingsState.searchAi
        onChanged: v => { SettingsState.searchAi = v; SettingsState.save() }
    }
    SettingToggle {
        label: "Software search"; description: "Allow explicit package searches with p"
        checked: SettingsState.searchPackages
        onChanged: v => { SettingsState.searchPackages = v; SettingsState.save() }
    }

    Text { text: "Notifications"; color: Colors.textMuted; font.pixelSize: Theme.fontTiny; font.bold: true; font.family: Theme.fontFamily }
    SettingToggle {
        label: "Persistent history"; description: "Restore recent notifications after reloads"
        checked: SettingsState.notificationHistory
        onChanged: v => { SettingsState.notificationHistory = v; SettingsState.save() }
    }
    SettingToggle {
        label: "Group by application"; description: "Keep busy apps in a single visual group"
        checked: SettingsState.groupNotifications
        onChanged: v => { SettingsState.groupNotifications = v; SettingsState.save() }
    }

    GlassButton {
        anchors.horizontalCenter: parent.horizontalCenter
        icon: "󰒓"; label: "Restore defaults"
        onClicked: SettingsState.reset()
    }

    Text { text: "Health"; color: Colors.textMuted; font.pixelSize: Theme.fontTiny; font.bold: true; font.family: Theme.fontFamily }
    GlassSurface {
        width: parent.width; height: 52; level: "e1"; radius: Theme.radiusMedium
        Row {
            anchors { fill: parent; margins: Theme.spacingNormal }
            spacing: Theme.spacingNormal
            Text {
                text: root.health.errors > 0 ? "󰅚" : root.health.warnings > 0 ? "󰀦" : "󰄬"
                color: root.health.errors > 0 ? Colors.error : root.health.warnings > 0 ? Colors.warning : Colors.success
                font.pixelSize: Theme.fontLarge; font.family: Theme.fontIcon; anchors.verticalCenter: parent.verticalCenter
            }
            Column {
                width: parent.width - 90; anchors.verticalCenter: parent.verticalCenter
                Text { text: root.health.errors === 0 && root.health.warnings === 0 ? "Desktop healthy" : root.health.errors + " errors · " + root.health.warnings + " warnings"; color: Colors.text; font.pixelSize: Theme.fontSmall; font.bold: true; font.family: Theme.fontFamily }
                Text { width: parent.width; text: root.health.issues.length ? root.health.issues[0] : "Generated state and dependencies look good"; color: Colors.textMuted; elide: Text.ElideRight; font.pixelSize: Theme.fontTiny; font.family: Theme.fontFamily }
            }
            GlassButton { icon: "󰑐"; hPadding: 8; vPadding: 5; onClicked: doctor.running = true }
        }
    }
    Row {
        anchors.horizontalCenter: parent.horizontalCenter; spacing: Theme.spacingSmall
        GlassButton { icon: "󰁯"; label: "Backup"; onClicked: { actionProc.command = [Quickshell.env("HOME") + "/.config/scripts/dotfiles-backup.sh"]; actionProc.running = true } }
        GlassButton { icon: "󰍉"; label: "Full report"; onClicked: { actionProc.command = ["kitty", "--class=floating", "-e", Quickshell.env("HOME") + "/.config/scripts/dotfiles-doctor.sh"]; actionProc.running = true } }
    }
}
