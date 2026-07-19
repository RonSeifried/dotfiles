pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Night light (color temperature) via wl-gammarelay-rs over its D-Bus iface
// rs.wl-gammarelay (path /, prop Temperature q, 1000–10000K; 6500 = neutral).
// The daemon itself is owned by niri (spawn-at-startup) so it survives shell
// restarts; this singleton only reads/sets the temperature.
Singleton {
    id: root

    readonly property int neutralTemp: 6500
    property int nightTemp: 4500   // matches the Mod+F9 keybind's historic value
    property int temperature: 6500
    readonly property bool on: temperature < neutralTemp

    Component.onCompleted: readProc.running = true

    // busctl get-property → "q 4500"
    Process {
        id: readProc
        command: ["busctl", "--user", "get-property", "rs.wl-gammarelay", "/", "rs.wl.gammarelay", "Temperature"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.trim().match(/(\d+)/)
                if (m) root.temperature = parseInt(m[1])
            }
        }
    }

    Process { id: setProc }
    function setTemp(t) {
        root.temperature = Math.max(1000, Math.min(neutralTemp, Math.round(t)))
        setProc.command = ["busctl", "--user", "set-property", "rs.wl-gammarelay", "/",
                           "rs.wl.gammarelay", "Temperature", "q", String(root.temperature)]
        setProc.running = true
    }

    function enable()  { setTemp(nightTemp) }
    function disable() { setTemp(neutralTemp) }
    function toggle()  { if (on) disable(); else enable() }
}
