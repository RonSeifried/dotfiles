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

            LockSurface {
                id: lockSurfaceItem
                anchors.fill: parent
                context: lockContext
            }

            // Native compositor blur via ext-background-effect-v1 (qs 0.3 + niri 26.04).
            // Anchor the Region to the inner item (created with surface) so the
            // Region has a valid Item reference at instantiation time.
            BackgroundEffect.blurRegion: Region { item: lockSurfaceItem }
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
