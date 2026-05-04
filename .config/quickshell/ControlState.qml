pragma Singleton
import Quickshell

Singleton {
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
    property bool osdVolumeVisible: false
    property bool osdBrightnessVisible: false

    function togglePanel(name) {
        rightPanel = (rightPanel === name) ? "none" : name
    }
}
