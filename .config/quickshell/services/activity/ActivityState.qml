pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool recording: false
    property double recordingStarted: 0
    property var external: ({})
    readonly property bool active: recording || Object.keys(external).length > 0
    Process { id: actionProc }

    function stopRecording() {
        actionProc.command = [(Quickshell.env("HOME") || "") + "/.config/scripts/screenrecord.sh"]
        actionProc.running = true
    }
    function begin(id, label, icon) {
        if (id === "recording") {
            recording = true
            recordingStarted = Date.now()
        }
        const next = Object.assign({}, external)
        next[id] = ({ label: label, icon: icon, started: Date.now() })
        external = next
    }
    function end(id) {
        if (id === "recording") { recording = false; recordingStarted = 0 }
        const next = Object.assign({}, external)
        delete next[id]
        external = next
    }
}
