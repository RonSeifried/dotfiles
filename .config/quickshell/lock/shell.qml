import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: shell

    LockContext {
        id: lockContext
        onUnlocked: sessionLock.locked = false
    }

    WlSessionLock {
        id: sessionLock
        locked: false

        WlSessionLockSurface {
            id: surface
            color: "transparent"
            // Native compositor blur via ext-background-effect-v1 (qs 0.3 + niri 26.04).
            // Niri blurs whatever it renders behind the session-lock surface; LockSurface
            // sits on top with a dim overlay for contrast.
            BackgroundEffect.blurRegion: Region { item: surface.contentItem }

            LockSurface {
                anchors.fill: parent
                context: lockContext
            }
        }
    }

    IpcHandler {
        target: "lock"

        function lock() {
            lockContext.resetForLock()
            sessionLock.locked = true
        }
    }
}
