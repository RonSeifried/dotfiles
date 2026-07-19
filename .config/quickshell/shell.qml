//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io

import "bar"
import "bar/popups"
import "launcher"
import "osd"
import "menus"
import "services/mcp"
import "services/performance"
import "services/polkit"

ShellRoot {
    id: shellRoot
    readonly property bool _powerPolicyActive: PowerPolicy.autoPerformance

    // Transient surfaces and state services are composed here for atomic reloads.

    // Effective screen for popups (launcher, menus, OSD).
    // Bar-set override > niri keyboard/mouse focused output > first screen (boot fallback).
    readonly property string targetScreen: ControlState.activeScreen
        || WMState.focusedOutput
        || (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "")

    // ── Bar — one per screen ────────────────────────────────────
    Variants {
        model: Quickshell.screens
        delegate: Bar {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: AudioSwitcher {
            required property var modelData
            screen: modelData
            open: ControlState.audioSwitcherOpen && modelData.name === shellRoot.targetScreen
        }
    }

    // ── Launcher ───────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        delegate: Launcher {
            required property var modelData
            screen: modelData
            open: ControlState.launcherOpen && modelData.name === shellRoot.targetScreen
        }
    }

    // ── OSD ────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        delegate: Osd {
            required property var modelData
            screen: modelData
            active: modelData.name === shellRoot.targetScreen
        }
    }

    // ── Power Menu ─────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        delegate: PowerMenu {
            required property var modelData
            screen: modelData
            open: ControlState.powerMenuOpen && modelData.name === shellRoot.targetScreen
        }
    }

    // ── Clipboard ───────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        delegate: ClipboardMenu {
            required property var modelData
            screen: modelData
            open: ControlState.clipboardOpen && modelData.name === shellRoot.targetScreen
        }
    }

    // ── Wallpaper Picker ────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        delegate: WallpaperPicker {
            required property var modelData
            screen: modelData
            open: ControlState.wallpaperPickerOpen && modelData.name === shellRoot.targetScreen
        }
    }

    // ── Polkit Auth Overlay ─────────────────────────────────────
    Variants {
        model: Quickshell.screens
        delegate: PolkitOverlay {
            required property var modelData
            screen: modelData
            active: modelData.name === shellRoot.targetScreen
        }
    }

    // ── MCP Manager (single floating window, not per-screen) ────
    // The Docker manager is the largest optional shell feature. Keep its QML
    // and Docker queries out of the always-on bar process until explicitly
    // requested.
    Loader {
        id: mcpLoader
        active: false
        sourceComponent: Component { McpManager { visible: true } }
    }

    // ── Performance Panel ───────────────────────────────────────
    Variants {
        model: Quickshell.screens
        delegate: PerfPanel {
            required property var modelData
            screen: modelData
            open: ControlState.perfPanelOpen && modelData.name === shellRoot.targetScreen
        }
    }

    // PerfState collector subprocess runs only when something is consuming it.
    // Singleton-to-singleton Binding{} can race with QML init; explicit
    // Connections + an onComplete primer is more reliable.
    Connections {
        target: ControlState
        function onPerfPillVisibleChanged() { PerfState.active = ControlState.perfPillVisible || ControlState.perfPanelOpen }
        function onPerfPanelOpenChanged()   { PerfState.active = ControlState.perfPillVisible || ControlState.perfPanelOpen }
    }
    Connections {
        target: SettingsState
        function onLoadedChanged() {
            if (SettingsState.loaded) ControlState.perfPillVisible = SettingsState.showPerformancePill
        }
    }
    Component.onCompleted: {
        ControlState.perfPillVisible = SettingsState.showPerformancePill
        PerfState.active = ControlState.perfPillVisible || ControlState.perfPanelOpen
    }

    // ── IPC ─────────────────────────────────────────────────────
    IpcHandler {
        target: "launcher"
        function toggle() {
            ControlState.activeScreen = WMState.focusedOutput
            ControlState.toggleTransient("launcher")
        }
        function ai() {
            ControlState.activeScreen = WMState.focusedOutput
            ControlState.launcherPrefill = "ai "
            ControlState.closeTransientOverlays("launcher")
            ControlState.launcherOpen = true
        }
    }

    IpcHandler {
        target: "power"
        function toggle() { ControlState.activeScreen = WMState.focusedOutput; ControlState.toggleTransient("power") }
    }

    IpcHandler {
        target: "clipboard"
        function toggle() { ControlState.activeScreen = WMState.focusedOutput; ControlState.toggleTransient("clipboard") }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle() { ControlState.activeScreen = WMState.focusedOutput; ControlState.toggleTransient("wallpaper") }
    }

    IpcHandler {
        target: "idle"
        function toggle() { ControlState.idleInhibited = !ControlState.idleInhibited }
    }

    IpcHandler {
        target: "panel"
        function close() { ControlState.rightPanel = "none" }
    }

    // Night light — the keybinds route through here (NOT raw busctl) so the
    // Control Center tile and the actual gamma state can never diverge.
    IpcHandler {
        target: "nightlight"
        function toggle()  { NightLightState.toggle() }
        function off()     { NightLightState.disable() }
        function set(temp: string) { NightLightState.setTemp(parseInt(temp)) }
    }

    IpcHandler {
        target: "control"
        // Open on the FOCUSED output (like every other popup via targetScreen),
        // not screens[0] — multi-monitor: the CC must follow the keyboard.
        function toggle() {
            if (ControlState.controlCenterOpen) { ControlState.closeControlCenter(); return }
            ControlState.activeScreen = WMState.focusedOutput
                || (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "")
            ControlState.openControlCenter("")
        }
        // Open straight into a detail section ("wifi" | "bluetooth" | "vpn" | "battery").
        function open(section: string) {
            ControlState.activeScreen = WMState.focusedOutput
                || (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "")
            ControlState.openControlCenter(section)
        }
    }

    IpcHandler {
        target: "mcp"
        function toggle() {
            if (!mcpLoader.active) { mcpLoader.active = true; return }
            if (mcpLoader.item) mcpLoader.item.visible = !mcpLoader.item.visible
        }
        function open()   { mcpLoader.active = true; Qt.callLater(() => { if (mcpLoader.item) mcpLoader.item.visible = true }) }
        function close()  { if (mcpLoader.item) mcpLoader.item.visible = false }
    }

    IpcHandler {
        target: "perf"
        function togglePill()  {
            ControlState.perfPillVisible = !ControlState.perfPillVisible
            SettingsState.showPerformancePill = ControlState.perfPillVisible
            SettingsState.save()
        }
        function togglePanel() { ControlState.activeScreen = WMState.focusedOutput; ControlState.toggleTransient("performance") }
        function close()       { ControlState.perfPanelOpen = false }
    }

    // Generic hook for scripts with long-running work (downloads, renders,
    // timers). Screen recording is detected automatically via its lock file.
    IpcHandler {
        target: "activity"
        function begin(id: string, label: string, icon: string) { ActivityState.begin(id, label, icon) }
        function end(id: string) { ActivityState.end(id) }
    }

    IpcHandler {
        target: "osd"
        function volume(v: string, muted: string) {
            ControlState.activeScreen = WMState.focusedOutput
            ControlState.osdVolume = parseFloat(v)
            ControlState.osdMuted = (muted === "1" || muted === "true" || muted === "yes")
            ControlState.osdVolumeRequested(ControlState.osdVolume, ControlState.osdMuted)
        }
        function brightness(v: string) {
            ControlState.activeScreen = WMState.focusedOutput
            ControlState.osdBrightness = parseFloat(v)
            ControlState.osdBrightnessRequested(ControlState.osdBrightness)
        }
    }

    IpcHandler {
        target: "audio"
        function switcher() { ControlState.activeScreen = WMState.focusedOutput; ControlState.toggleTransient("audio") }
    }
}
