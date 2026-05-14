pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Polkit

// PolkitAgent.path is one-shot (write-once); after a failed register call the
// listener stays dead until the object is torn down. To recover from a stale
// conflict (e.g. lxqt-policykit ran at boot, has since exited), bounce the
// Loader: agent recreates fresh → fires listener_register again.
Singleton {
    id: root

    readonly property var agent: agentLoader.item
    readonly property var flow: agent ? agent.flow : null
    readonly property bool active: flow !== null
    readonly property bool isRegistered: agent ? agent.isRegistered : false

    function retry() {
        agentLoader.active = false
        Qt.callLater(() => agentLoader.active = true)
    }

    Loader {
        id: agentLoader
        active: true
        sourceComponent: PolkitAgent { path: "/org/quickshell/PolkitAgent" }
    }

    // Auto-retry registration a few times on cold-start where another agent
    // may still be exiting. Gives up silently after retryMax.
    property int retryCount: 0
    readonly property int retryMax: 6
    Timer {
        interval: 1500
        running: !root.isRegistered && root.retryCount < root.retryMax
        repeat: true
        onTriggered: {
            root.retryCount++
            root.retry()
        }
    }
}
