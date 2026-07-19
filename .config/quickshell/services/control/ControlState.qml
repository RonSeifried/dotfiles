pragma Singleton
import Quickshell

Singleton {
    // Empty = fall back to WMState.focusedOutput (mouse/keyboard focused screen).
    // Bar interactions set this to their own screen so popups pin to the bar that was clicked.
    property string activeScreen: ""

    property bool launcherOpen: false
    // Prefill text consumed once by Launcher on next open (e.g. "ai " for Mod+A).
    property string launcherPrefill: ""
    property bool powerMenuOpen: false
    property bool clipboardOpen: false
    property bool wallpaperPickerOpen: false
    property bool audioSwitcherOpen: false
    property bool idleInhibited: false

    // Performance HUD — pill in bar (toggle with Mod+H), panel slides down
    // from screen top when the pill is clicked.
    property bool perfPillVisible: false
    property bool perfPanelOpen: false

    // Hover-driven bar dropdown. Only "mpris" remains ("none" = closed) — the
    // other panels moved into the Control Center.
    property string rightPanel: "none"

    // Control Center. ccSection: "" = main grid, "wifi"/"bluetooth" = detail morph.
    property bool controlCenterOpen: false
    property string ccSection: ""

    // Only one transient surface may own the desktop at once. Centralizing
    // this avoids overlapping scrims, conflicting keyboard focus and popups
    // that remain open behind a newly invoked surface.
    function closeTransientOverlays(except) {
        if (except !== "launcher") launcherOpen = false
        if (except !== "power") powerMenuOpen = false
        if (except !== "clipboard") clipboardOpen = false
        if (except !== "wallpaper") wallpaperPickerOpen = false
        if (except !== "audio") audioSwitcherOpen = false
        if (except !== "control") {
            controlCenterOpen = false
            ccSection = ""
        }
        if (except !== "performance") perfPanelOpen = false
        rightPanel = "none"
    }

    function toggleTransient(name) {
        const wasOpen = name === "launcher" ? launcherOpen
            : name === "power" ? powerMenuOpen
            : name === "clipboard" ? clipboardOpen
            : name === "wallpaper" ? wallpaperPickerOpen
            : name === "audio" ? audioSwitcherOpen
            : name === "performance" ? perfPanelOpen : false
        closeTransientOverlays(wasOpen ? "" : name)
        if (wasOpen) return
        if (name === "launcher") launcherOpen = true
        else if (name === "power") powerMenuOpen = true
        else if (name === "clipboard") clipboardOpen = true
        else if (name === "wallpaper") wallpaperPickerOpen = true
        else if (name === "audio") audioSwitcherOpen = true
        else if (name === "performance") perfPanelOpen = true
    }

    function openControlCenter(section) {
        const next = section ? section : ""
        if (controlCenterOpen) {
            ccSection = next
            return
        }
        closeTransientOverlays("control")
        ccSection = next
        controlCenterOpen = true
    }
    function closeControlCenter() {
        controlCenterOpen = false
        ccSection = ""
    }

    property real osdVolume: 0
    property real osdBrightness: 0
    property bool osdMuted: false

    // OSD requests — fired on every volume/brightness keypress.
    // Multi-monitor: all Osd instances receive, only active one shows.
    signal osdVolumeRequested(real v, bool muted)
    signal osdBrightnessRequested(real v)
}
