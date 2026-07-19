import QtQuick
import Quickshell
import Quickshell.Io
import "../.."

// Clipboard history is loaded once per shell and filtered in memory. This puts
// recent copied text into normal Spotlight without a subprocess per keypress.
Item {
    id: root
    visible: false
    property var entries: []
    property bool ready: false

    Process {
        id: loader
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = text.split("\n").filter(Boolean).map(line => {
                    const tab = line.indexOf("\t")
                    return { id: tab >= 0 ? line.slice(0, tab) : "", preview: tab >= 0 ? line.slice(tab + 1) : line }
                }).slice(0, 300)
                root.ready = true
            }
        }
    }
    Process { id: decodeProc }
    Component.onCompleted: loader.running = true

    function search(query) {
        if (!ready || query.length < 3) return []
        const q = query.toLowerCase(), out = []
        for (let i = 0; i < entries.length && out.length < 4; i++) {
            const e = entries[i], text = e.preview.toLowerCase()
            if (!text.includes(q)) continue
            out.push({
                providerId: "clipboard", icon: "", iconText: "󰅍",
                title: e.preview.replace(/^[^\t]*\t/, "").slice(0, 100),
                subtitle: "Recent clipboard item", badge: "Clipboard",
                score: 410 - i,
                onActivate: () => {
                    decodeProc.command = ["sh", "-c", "printf '%s\\t' \"$1\" | cliphist decode | wl-copy", "_", e.id]
                    decodeProc.running = true
                }
            })
        }
        return out
    }
}
