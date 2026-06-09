pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Night light via hyprsunset (the tool the niri keybinds already use; 4500K).
// `active` reflects whether hyprsunset is running; toggle() flips it.
Singleton {
    id: root
    property bool active: false
    property int temp: 4500

    function toggle() {
        if (active) offProc.running = true
        else onProc.running = true
        active = !active            // optimistic; the poll reconciles
    }

    Process { id: onProc;  command: ["sh", "-c", "pkill hyprsunset; hyprsunset -t " + root.temp] }
    Process { id: offProc; command: ["pkill", "hyprsunset"] }

    // pgrep exits 0 when running, 1 when not.
    Process {
        id: checkProc
        command: ["pgrep", "-x", "hyprsunset"]
        onExited: (code) => root.active = (code === 0)
    }

    Component.onCompleted: checkProc.running = true
    Timer { interval: 2000; running: true; repeat: true; onTriggered: checkProc.running = true }
}
