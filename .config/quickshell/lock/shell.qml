import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: shell

    // Pre-warm image cache: hidden Image loads wallpaper at qs startup
    // so LockSurface renders instantly on activation.
    Image {
        id: preloader
        source: "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
        cache: true
        asynchronous: false
        visible: false
        width: 1
        height: 1
    }

    LockContext {
        id: lockContext
        onUnlocked: sessionLock.locked = false
    }

    WlSessionLock {
        id: sessionLock
        locked: false

        WlSessionLockSurface {
            id: surface
            LockSurface {
                anchors.fill: parent
                context: lockContext
                screenName: surface.screen.name
            }
        }
    }

    Process {
        id: grimProc
        // Captures one PNG per niri output → /tmp/qs-lock-<output>.png
        // jq is part of the dotfiles toolchain (used by pywal scripts).
        // Single sh -c so we can iterate outputs synchronously before locking.
        command: ["sh", "-c",
            "for o in $(niri msg --json outputs | jq -r 'keys[]'); do " +
            "  grim -o \"$o\" \"/tmp/qs-lock-$o.png\" || true; " +
            "done"]
        onExited: code => {
            // Lock surface comes up regardless — fallback to wallpaper if grim failed.
            sessionLock.locked = true
        }
    }

    Process {
        id: cleanupProc
        command: ["sh", "-c", "rm -f /tmp/qs-lock-*.png"]
    }

    Connections {
        target: sessionLock
        function onLockedChanged() {
            if (!sessionLock.locked) cleanupProc.running = true
        }
    }

    IpcHandler {
        target: "lock"

        function lock() {
            lockContext.resetForLock()
            // Async chain: grim captures all outputs → onExited sets locked=true.
            // ~100-200ms latency, matches hyprlock behavior.
            grimProc.running = true
        }

        function reload() {
            preloader.source = ""
            preloader.source = "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
        }
    }
}
