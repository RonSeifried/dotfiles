//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io

import "bar"
import "launcher"
import "osd"
import "menus"

ShellRoot {

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
            open: ControlState.launcherOpen
            onOpenChanged: ControlState.launcherOpen = open
        }
    }

    // ── OSD ────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        delegate: Osd {
            required property var modelData
            screen: modelData
        }
    }

    // ── Power Menu ─────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        delegate: PowerMenu {
            required property var modelData
            screen: modelData
            open: ControlState.powerMenuOpen
            onOpenChanged: ControlState.powerMenuOpen = open
        }
    }

    // ── Clipboard ───────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        delegate: ClipboardMenu {
            required property var modelData
            screen: modelData
            open: ControlState.clipboardOpen
            onOpenChanged: ControlState.clipboardOpen = open
        }
    }

    // ── Wallpaper Picker ────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        delegate: WallpaperPicker {
            required property var modelData
            screen: modelData
            open: ControlState.wallpaperPickerOpen
            onOpenChanged: ControlState.wallpaperPickerOpen = open
        }
    }

    // ── IPC ─────────────────────────────────────────────────────
    IpcHandler {
        target: "launcher"
        function toggle() { ControlState.launcherOpen = !ControlState.launcherOpen }
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
        target: "osd"
        function volume(v: string, muted: string) {
            ControlState.osdVolume = parseFloat(v)
            ControlState.osdMuted = (muted === "1" || muted === "true" || muted === "yes")
            ControlState.osdVolumeVisible = true
        }
        function brightness(v: string) {
            ControlState.osdBrightness = parseFloat(v)
            ControlState.osdBrightnessVisible = true
        }
    }
}
