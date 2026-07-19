import QtQuick
import Quickshell
import Quickshell.Io

// Files provider — queries the system's persistent plocate index. The helper
// falls back to fd when no index is present, but normal queries never traverse
// HOME on every keystroke.
Item {
    id: root
    visible: false

    readonly property string providerId: "files"
    readonly property string badge: "File"

    property string query: ""
    property var results: []
    property string _lastResolvedQuery: ""
    readonly property string helperPath: (Quickshell.env("HOME") || "")
        + "/.config/quickshell/launcher/providers/content-search.py"

    signal resultsReady(string query, var list)

    Timer {
        id: debounce
        interval: 110
        repeat: false
        onTriggered: root._run()
    }

    Process {
        id: fdProc
        stdout: StdioCollector { id: searchOut }
        onExited: {
            const out = []
            try {
                const items = JSON.parse(searchOut.text || "[]")
                for (let i = 0; i < items.length && out.length < 50; i++) out.push(_toResult(items[i]))
            } catch (e) {
                console.warn("FilesProvider: invalid index response:", e)
            }
            root.results = out
            root.resultsReady(root._lastResolvedQuery, out)
        }
    }

    Process { id: openProc }

    onQueryChanged: {
        const q = (query || "").trim()
        if (fdProc.running) fdProc.running = false
        if (!q) {
            results = []
            _lastResolvedQuery = ""
            resultsReady("", [])
            return
        }
        debounce.restart()
    }

    function _run() {
        _lastResolvedQuery = query.trim()
        fdProc.command = ["python3", helperPath, _lastResolvedQuery]
        fdProc.running = true
    }

    function _basename(p) {
        const i = p.lastIndexOf("/")
        return i >= 0 ? p.slice(i + 1) : p
    }
    function _dirname(p) {
        const i = p.lastIndexOf("/")
        return i >= 0 ? p.slice(0, i) : ""
    }
    function _looksLikeDir(p) {
        return p.endsWith("/") || (!_basename(p).includes(".") && !p.includes(" "))
    }

    function _open(path) {
        openProc.command = ["xdg-open", path]
        openProc.running = true
    }

    function _toResult(item) {
        const path = item.path
        const dir = item.kind === "Folder"
        const usageKey = "file:" + path
        return {
            providerId: providerId,
            icon: "",
            iconText: dir ? "" : "",
            title: item.title || _basename(path) || path,
            subtitle: _dirname(path),
            badge: item.kind || badge,
            path: path,
            score: (item.score || 0) + UsageState.score(usageKey),
            usageKey: usageKey,
            onActivate: () => { UsageState.record(usageKey); _open(path) }
        }
    }
}
