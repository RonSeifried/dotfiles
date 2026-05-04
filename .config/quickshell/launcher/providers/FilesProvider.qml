import QtQuick
import Quickshell
import Quickshell.Io

// Files provider — fuzzy-finds files via `fd`. Async, debounced.
// Triggered only via "f " prefix to avoid spawning fd on every default keystroke.
Item {
    id: root
    visible: false

    readonly property string providerId: "files"
    readonly property string badge: "File"

    property string query: ""
    property var results: []
    property string _lastResolvedQuery: ""
    property var _lines: []

    signal resultsReady(string query, var list)

    Timer {
        id: debounce
        interval: 200
        repeat: false
        onTriggered: root._run()
    }

    Process {
        id: fdProc
        stdout: SplitParser {
            onRead: line => { if (line) root._lines.push(line) }
        }
        onExited: {
            const lines = root._lines.slice()
            root._lines = []
            const out = []
            for (let i = 0; i < lines.length && out.length < 50; i++) {
                out.push(_toResult(lines[i]))
            }
            root.results = out
            root.resultsReady(root._lastResolvedQuery, out)
        }
    }

    Process { id: openProc }

    onQueryChanged: {
        const q = (query || "").trim()
        if (!q) {
            results = []
            _lastResolvedQuery = ""
            resultsReady("", [])
            return
        }
        debounce.restart()
    }

    function _run() {
        _lines = []
        _lastResolvedQuery = query.trim()
        const home = Quickshell.env("HOME") || "/home"
        // Search HOME, files+dirs, smart-case (default), no color codes.
        fdProc.command = ["fd", "--max-results", "50", "--color", "never", "--", _lastResolvedQuery, home]
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

    function _toResult(path) {
        const dir = _looksLikeDir(path)
        return {
            providerId: providerId,
            icon: "",
            iconText: dir ? "" : "",
            title: _basename(path) || path,
            subtitle: _dirname(path),
            badge: badge,
            score: 400,
            onActivate: () => _open(path)
        }
    }
}
