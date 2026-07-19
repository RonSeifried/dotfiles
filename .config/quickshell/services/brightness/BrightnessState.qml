pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "lib/brightnessMath.js" as Calc
import "../control"

// Backlight brightness via brightnessctl (same tool scripts/qs-osd.sh uses).
// `available` is false on machines with no backlight (the CC hides the slider).
Singleton {
    id: root

    property bool available: false
    property int _cur: 0
    property int _max: 1
    readonly property real value: Calc.frac(_cur, _max)

    function set(frac) {
        if (!available) return
        setProc.command = ["brightnessctl", "set", Calc.pct(frac) + "%", "-q"]
        setProc.running = true
    }

    function _refresh() { infoProc.running = true }

    // `brightnessctl -m info` → "name,class,cur,pct,max" (single line).
    Process {
        id: infoProc
        command: ["brightnessctl", "-m", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim()
                if (!line) { root.available = false; return }
                const f = line.split(",")
                if (f.length < 5) { root.available = false; return }
                root._cur = parseInt(f[2]) || 0
                root._max = parseInt(f[4]) || 1
                root.available = root._max > 1
            }
        }
    }

    Process {
        id: setProc
        onExited: root._refresh()
    }

    Component.onCompleted: _refresh()

    // External changes matter while the slider is visible. Keyboard changes
    // already report their value through the OSD IPC, so an always-on poll was
    // just waking the shell once per second on an untouched desktop.
    Timer { interval: 1500; running: ControlState.controlCenterOpen; repeat: true; onTriggered: root._refresh() }
}
