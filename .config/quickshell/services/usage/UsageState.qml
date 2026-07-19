pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var entries: ({})
    readonly property string statePath: (Quickshell.env("HOME") || "")
        + "/.local/state/quickshell/usage.json"
    readonly property string helperPath: (Quickshell.env("HOME") || "")
        + "/.config/quickshell/services/usage/usage-helper.py"

    Process {
        id: stateLoader
        command: ["sh", "-c", "test -r \"$1\" && cat \"$1\"", "_", root.statePath]
        stdout: StdioCollector { id: stateOut }
        onExited: code => {
            if (code !== 0) { root.entries = ({}); return }
            try { root.entries = JSON.parse(stateOut.text || "{}") }
            catch (e) { root.entries = ({}) }
        }
    }

    Component.onCompleted: stateLoader.running = true

    property var _writeQueue: []
    Process {
        id: writer
        property string pendingKey: ""
        stdinEnabled: true
        onStarted: {
            write(pendingKey)
            pendingKey = ""
        }
        onExited: root._flushWriteQueue()
    }

    function score(key) {
        const item = entries[key]
        if (!item) return 0
        const ageHours = Math.max(0, Date.now() - (item.last || 0)) / 3600000
        const recency = 220 / (1 + ageHours / 24)
        return Math.min(360, (item.count || 0) * 22 + recency)
    }

    function record(key) {
        if (!key) return
        const next = Object.assign({}, entries)
        const old = next[key] || ({ count: 0, last: 0 })
        next[key] = ({ count: old.count + 1, last: Date.now() })
        entries = next
        _writeQueue = _writeQueue.concat([key])
        _flushWriteQueue()
    }

    function _flushWriteQueue() {
        if (writer.running || _writeQueue.length === 0) return
        const queue = _writeQueue.slice()
        const key = queue.shift()
        _writeQueue = queue
        writer.pendingKey = key
        writer.command = ["python3", helperPath, statePath, "-"]
        writer.running = true
    }
}
