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

    // Effective screen for popups (launcher, menus, OSD).
    // Bar-set override > niri keyboard/mouse focused output > first screen (boot fallback).
    readonly property string targetScreen: ControlState.activeScreen
        || NiriState.focusedOutput
        || (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "")

    // ── Bar — one per screen ────────────────────────────────────
    Variants {
        model: Quickshell.screens
        delegate: Bar {
            required property var modelData
            screen: modelData
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
    McpManager {
        id: mcpManager
        visible: false
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
    Component.onCompleted: PerfState.active = ControlState.perfPillVisible || ControlState.perfPanelOpen

    // ── IPC ─────────────────────────────────────────────────────
    IpcHandler {
        target: "launcher"
        function toggle() { ControlState.launcherOpen = !ControlState.launcherOpen }
        function ai() {
            ControlState.launcherPrefill = "ai "
            ControlState.launcherOpen = true
        }
    }

    IpcHandler {
        target: "power"
        function toggle() { ControlState.powerMenuOpen = !ControlState.powerMenuOpen }
    }

    IpcHandler {
        target: "clipboard"
        function toggle() { ControlState.clipboardOpen = !ControlState.clipboardOpen }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle() { ControlState.wallpaperPickerOpen = !ControlState.wallpaperPickerOpen }
    }

    IpcHandler {
        target: "idle"
        function toggle() { ControlState.idleInhibited = !ControlState.idleInhibited }
    }

    IpcHandler {
        target: "notifications"
        function toggle() { ControlState.togglePanel("notif") }
    }

    IpcHandler {
        target: "panel"
        function close() { ControlState.rightPanel = "none" }
    }

    IpcHandler {
        target: "mcp"
        function toggle() { mcpManager.visible = !mcpManager.visible }
        function open()   { mcpManager.visible = true }
        function close()  { mcpManager.visible = false }
    }

    IpcHandler {
        target: "perf"
        function togglePill()  { ControlState.perfPillVisible = !ControlState.perfPillVisible }
        function togglePanel() { ControlState.perfPanelOpen = !ControlState.perfPanelOpen }
        function close()       { ControlState.perfPanelOpen = false }
    }

    IpcHandler {
        target: "osd"
        function volume(v: string, muted: string) {
            ControlState.osdVolume = parseFloat(v)
            ControlState.osdMuted = (muted === "1" || muted === "true" || muted === "yes")
            ControlState.osdVolumeRequested(ControlState.osdVolume, ControlState.osdMuted)
        }
        function brightness(v: string) {
            ControlState.osdBrightness = parseFloat(v)
            ControlState.osdBrightnessRequested(ControlState.osdBrightness)
        }
    }
}
