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
            LockSurface {
                anchors.fill: parent
                context: lockContext
            }
        }
    }

    IpcHandler {
        target: "lock"

        function lock() {
            lockContext.currentText = ""
            lockContext.showFailure = false
            sessionLock.locked = true
        }

        function reload() {
            preloader.source = ""
            preloader.source = "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
        }
    }
}
