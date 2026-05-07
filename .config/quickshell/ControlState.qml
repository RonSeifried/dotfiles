pragma Singleton
import Quickshell

Singleton {
    // Empty = fall back to NiriState.focusedOutput (mouse/keyboard focused screen).
    // Bar interactions set this to their own screen so popups pin to the bar that was clicked.
    property string activeScreen: ""

    property bool launcherOpen: false
    property bool powerMenuOpen: false
    property bool clipboardOpen: false
    property bool wallpaperPickerOpen: false
    property bool idleInhibited: false

    // "none" | "notif" | "audio" | "battery"
    property string rightPanel: "none"

    property real osdVolume: 0
    property real osdBrightness: 0
    property bool osdMuted: false

    // OSD requests — fired on every volume/brightness keypress.
    // Multi-monitor: all Osd instances receive, only active one shows.
    signal osdVolumeRequested(real v, bool muted)
    signal osdBrightnessRequested(real v)

    function togglePanel(name) {
        rightPanel = (rightPanel === name) ? "none" : name
    }
}
