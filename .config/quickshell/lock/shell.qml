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

            // No BackgroundEffect here: its attached type only accepts
            // ProxyWindowBase/WindowInterface (PanelWindow etc.), not
            // WlSessionLockSurface — attaching aborts surface creation and
            // kills the lock daemon (qs 0.3, unchanged upstream as of 2026-07).
            // The dim overlay lives in LockSurface; niri shows its backdrop
            // color behind the transparent surface.
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
