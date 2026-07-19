pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Versioned, user-owned desktop preferences.  Generated palette data stays in
// ~/.cache; choices belong in ~/.config so they survive cache cleanup.
Singleton {
    id: root

    readonly property int schemaVersion: 1
    readonly property string statePath: (Quickshell.env("HOME") || "") + "/.config/quickshell/settings.json"
    readonly property string helperPath: (Quickshell.env("HOME") || "") + "/.config/quickshell/services/settings/settings-helper.py"

    property bool loaded: false
    property bool _applying: false
    property bool _pendingSave: false

    // Appearance
    property real materialOpacity: 1.0
    property real accentStrength: 1.0
    property string motion: "normal"       // normal | reduced | off
    property bool adaptiveMaterial: true

    // Bar / surfaces
    property bool showPerformancePill: false
    property bool showMediaInBar: true
    property bool showTray: true

    // Search
    property bool searchFiles: true
    property bool searchWeb: true
    property bool searchWindows: true
    property bool searchPackages: true
    property bool searchAi: true

    // Notifications
    property bool notificationHistory: true
    property bool groupNotifications: true
    property bool hideSensitiveOnLock: true

    // Wallpaper and power
    property string wallpaperTransition: "grow"
    property real wallpaperTransitionDuration: 0.7
    property bool autoPerformanceOnAc: false
    property real suitableChargerWatts: 45

    signal saved()

    function defaults() {
        return {
            schemaVersion: schemaVersion,
            appearance: { materialOpacity: 1.0, accentStrength: 1.0, motion: "normal", adaptiveMaterial: true },
            bar: { showPerformancePill: false, showMedia: true, showTray: true },
            search: { files: true, web: true, windows: true, packages: true, ai: true },
            notifications: { history: true, grouped: true, hideSensitiveOnLock: true },
            wallpaper: { transition: "grow", duration: 0.7 },
            power: { autoPerformanceOnAc: false, suitableChargerWatts: 45 }
        }
    }

    function snapshot() {
        return {
            schemaVersion: schemaVersion,
            appearance: { materialOpacity, accentStrength, motion, adaptiveMaterial },
            bar: { showPerformancePill, showMedia: showMediaInBar, showTray },
            search: { files: searchFiles, web: searchWeb, windows: searchWindows, packages: searchPackages, ai: searchAi },
            notifications: { history: notificationHistory, grouped: groupNotifications, hideSensitiveOnLock },
            wallpaper: { transition: wallpaperTransition, duration: wallpaperTransitionDuration },
            power: { autoPerformanceOnAc, suitableChargerWatts }
        }
    }

    function apply(data) {
        const d = data || defaults()
        const a = d.appearance || {}, b = d.bar || {}, s = d.search || {}
        const n = d.notifications || {}, w = d.wallpaper || {}, p = d.power || {}
        _applying = true
        materialOpacity = Math.max(0.72, Math.min(1, Number(a.materialOpacity ?? 1)))
        accentStrength = Math.max(0.55, Math.min(1.35, Number(a.accentStrength ?? 1)))
        motion = ["normal", "reduced", "off"].indexOf(a.motion) >= 0 ? a.motion : "normal"
        adaptiveMaterial = a.adaptiveMaterial ?? true
        showPerformancePill = b.showPerformancePill ?? false
        showMediaInBar = b.showMedia ?? true
        showTray = b.showTray ?? true
        searchFiles = s.files ?? true; searchWeb = s.web ?? true; searchWindows = s.windows ?? true
        searchPackages = s.packages ?? true; searchAi = s.ai ?? true
        notificationHistory = n.history ?? true; groupNotifications = n.grouped ?? true
        hideSensitiveOnLock = n.hideSensitiveOnLock ?? true
        wallpaperTransition = w.transition || "grow"
        wallpaperTransitionDuration = Math.max(0, Math.min(3, Number(w.duration ?? 0.7)))
        autoPerformanceOnAc = p.autoPerformanceOnAc ?? false
        suitableChargerWatts = Math.max(15, Math.min(240, Number(p.suitableChargerWatts ?? 45)))
        _applying = false; loaded = true
    }

    function save() {
        if (!loaded || _applying) return
        if (writer.running) { _pendingSave = true; return }
        writer.command = ["python3", helperPath, "write", statePath, JSON.stringify(snapshot())]
        writer.running = true
    }

    function reset() { apply(defaults()); save() }

    FileView {
        id: stateFile
        path: root.statePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.apply(JSON.parse(text())) }
            catch (e) { console.warn("SettingsState: invalid settings, using defaults:", e); root.apply(root.defaults()) }
        }
        onLoadFailed: { if (!root.loaded) { root.apply(root.defaults()); root.save() } }
    }

    Process {
        id: writer
        onExited: code => {
            if (code === 0) root.saved()
            if (root._pendingSave) { root._pendingSave = false; Qt.callLater(() => root.save()) }
        }
    }
}
