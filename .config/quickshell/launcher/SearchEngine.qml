import QtQuick
import "providers"

// Aggregates providers, parses prefix, merges + sorts.
// Mode prefixes:
//   "= expr"  → calc only
//   "> name"  → system actions only (empty prefix lists all)
//   "? text"  → web only
//   "w name"  → niri windows only
//   "f name"  → file search via fd (async, debounced)
// No prefix → apps + windows + system (matches) + calc (auto if numeric) + web fallback.
Item {
    id: root
    visible: false

    property string query: ""
    property var results: []
    property string mode: "default"   // "default" | "calc" | "system" | "web" | "window" | "files"
    property string modeHint: ""

    AppsProvider       { id: appsP }
    CalcProvider       { id: calcP }
    SystemProvider     { id: sysP }
    NiriWindowProvider { id: winP }
    WebProvider        { id: webP }
    FilesProvider      { id: filesP }

    Connections {
        target: filesP
        function onResultsReady(q, list) {
            if (root.mode !== "files") return
            if (q !== root._currentRest()) return
            if (!list.length) {
                root.results = [{
                    providerId: "files",
                    icon: "", iconText: "",
                    title: "No files found",
                    subtitle: q,
                    badge: "File",
                    score: 0,
                    onActivate: () => {}
                }]
            } else {
                root.results = list
            }
        }
    }

    onQueryChanged: _recompute()
    Component.onCompleted: _recompute()

    function _currentRest() {
        return _parseMode((query || "").trim()).rest
    }

    function _parseMode(q) {
        if (q.startsWith("="))                       return { mode: "calc",   rest: q.slice(1).trim(), hint: "calculator" }
        if (q.startsWith(">"))                       return { mode: "system", rest: q.slice(1).trim(), hint: "actions"    }
        if (q.startsWith("?"))                       return { mode: "web",    rest: q.slice(1).trim(), hint: "web search" }
        if (q.startsWith("w ") || q === "w")         return { mode: "window", rest: q.slice(1).trim(), hint: "windows"    }
        if (q.startsWith("f ") || q === "f")         return { mode: "files",  rest: q.slice(1).trim(), hint: "files"      }
        return { mode: "default", rest: q, hint: "" }
    }

    function _searchingPlaceholder(q) {
        return [{
            providerId: "files",
            icon: "", iconText: "",
            title: "Searching…",
            subtitle: q,
            badge: "File",
            score: 0,
            onActivate: () => {}
        }]
    }

    function _recompute() {
        const trimmed = (query || "").trim()
        const parsed = _parseMode(trimmed)
        mode = parsed.mode
        modeHint = parsed.hint

        let out = []
        if (parsed.mode === "calc") {
            out = calcP.search(parsed.rest)
            if (!out.length && parsed.rest) {
                out = [{
                    providerId: "calc",
                    icon: "", iconText: "",
                    title: "Invalid expression",
                    subtitle: "Use digits, + - * / ( ) . , % ^",
                    badge: "=",
                    score: 0,
                    onActivate: () => {}
                }]
            }
        } else if (parsed.mode === "system") {
            out = parsed.rest ? sysP.search(parsed.rest) : sysP.listAll()
        } else if (parsed.mode === "web") {
            out = webP.search(parsed.rest)
        } else if (parsed.mode === "window") {
            out = winP.search(parsed.rest)
        } else if (parsed.mode === "files") {
            filesP.query = parsed.rest
            if (!parsed.rest) {
                out = [{
                    providerId: "files",
                    icon: "", iconText: "",
                    title: "Type to search files in $HOME",
                    subtitle: "Powered by fd",
                    badge: "File",
                    score: 0,
                    onActivate: () => {}
                }]
            } else if (filesP.results.length && filesP._lastResolvedQuery === parsed.rest) {
                out = filesP.results
            } else {
                out = _searchingPlaceholder(parsed.rest)
            }
        } else {
            // Default mode — merge.
            if (!parsed.rest) {
                out = appsP.search("")
            } else {
                const apps = appsP.search(parsed.rest)
                const wins = winP.search(parsed.rest)
                const sys  = sysP.search(parsed.rest)
                const calc = calcP.search(parsed.rest)
                out = calc.concat(apps).concat(wins).concat(sys)
                out.sort((a, b) => b.score - a.score)
                out = out.slice(0, 12)
                const web = webP.search(parsed.rest)
                if (web.length) out = out.concat(web.slice(0, 1))
            }
        }
        results = out
    }
}
