import QtQuick
import "providers"

// Aggregates providers, parses prefix, merges + sorts.
// Mode prefixes:
//   "= expr"   → calc only
//   "> name"   → system actions only (empty prefix lists all)
//   "? text"   → web only
//   "w name"   → niri windows only
//   "f name"   → file search via fd (async, debounced)
//   "p name"   → package search (pacman + AUR)
//   "ai text"  → AI assistant (Gemini streaming) — Enter submits, history persists
// No prefix → apps + windows + system (matches) + calc (auto if numeric) + web fallback.
Item {
    id: root
    visible: false

    property string query: ""
    property var results: []
    property string mode: "default"   // "default" | "calc" | "system" | "web" | "window" | "files" | "pkg" | "ai"
    property string modeHint: ""
    property string effectiveFileQuery: ""

    readonly property alias ai: aiP

    AppsProvider       { id: appsP }
    CalcProvider       { id: calcP }
    SystemProvider     { id: sysP }
    NiriWindowProvider { id: winP }
    WebProvider        { id: webP }
    FilesProvider      { id: filesP }
    PkgProvider        { id: pkgP }
    AiProvider         { id: aiP }
    ClipboardProvider  { id: clipP }

    // Recompute when pkg lists finish loading mid-session.
    Connections {
        target: pkgP
        function onReadyChanged() { if (root.mode === "pkg") root._recompute() }
    }
    Connections { target: clipP; function onReadyChanged() { if (root.mode === "default") root._recompute() } }

    Connections {
        target: filesP
        function onResultsReady(q, list) {
            if (root.mode !== "files" && root.mode !== "default") return
            if (q !== root.effectiveFileQuery) return
            if (root.mode === "default") { root._recompute(); return }
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
        if (q.startsWith("ai ") || q === "ai")       return { mode: "ai",     rest: q.slice(2).trim(), hint: "ask AI"     }
        if (q.startsWith("w ") || q === "w")         return { mode: "window", rest: q.slice(1).trim(), hint: "windows"    }
        if (q.startsWith("f ") || q === "f")         return { mode: "files",  rest: q.slice(1).trim(), hint: "files"      }
        if (q.startsWith("p ") || q === "p")         return { mode: "pkg",    rest: q.slice(1).trim(), hint: "packages"   }
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

    function _take(list, count, boost) {
        return list.slice(0, count).map(r => {
            const copy = Object.assign({}, r)
            copy.score = (copy.score || 0) + boost
            return copy
        })
    }

    function _looksLikeFileIntent(q) {
        return q.includes("/") || q.includes(".")
            || /\b(file|folder|document|image|photo|pdf|config|script)\b/i.test(q)
    }

    function _looksLikeActionIntent(q) {
        return /^(open|launch|start|stop|toggle|turn|enable|disable|lock|sleep|reboot|shutdown|focus|switch|change)\b/i.test(q)
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
        } else if (parsed.mode === "pkg") {
            out = SettingsState.searchPackages ? pkgP.search(parsed.rest) : [{
                providerId: "pkg", icon: "", iconText: "󰅖", title: "Package search is disabled",
                subtitle: "Enable it in Desktop Settings", badge: "Pkg", score: 0, onActivate: () => {}
            }]
        } else if (parsed.mode === "ai") {
            // AI-mode renders via AiView, not ResultList. Results stay empty.
            out = []
        } else if (parsed.mode === "files") {
            effectiveFileQuery = parsed.rest
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
            // Unified Spotlight mode: every local provider participates and
            // prefixes remain optional filters for power users.
            if (!parsed.rest) {
                out = appsP.search("")
                effectiveFileQuery = ""
                filesP.query = ""
            } else {
                const fileIntent = _looksLikeFileIntent(parsed.rest)
                const actionIntent = _looksLikeActionIntent(parsed.rest)
                const subject = parsed.rest.replace(/^(open|launch|start|find|show)\s+/i, "").trim() || parsed.rest
                effectiveFileQuery = SettingsState.searchFiles && subject.length >= 2 ? subject : ""
                filesP.query = effectiveFileQuery
                const apps = _take(appsP.search(subject), 5, fileIntent ? -120 : 180)
                const wins = SettingsState.searchWindows ? _take(winP.search(subject), 3, 120) : []
                const sys  = _take(sysP.search(parsed.rest), 3, actionIntent ? 260 : 0)
                const calc = calcP.search(parsed.rest)
                const files = filesP._lastResolvedQuery === effectiveFileQuery
                    ? _take(filesP.results, fileIntent ? 8 : 4, fileIntent ? 220 : -80) : []
                const clips = _take(clipP.search(subject), 3, /\b(copy|clipboard|paste)\b/i.test(parsed.rest) ? 260 : -40)
                // Packages are an explicit specialist scope (`p query`). They
                // are not a reasonable default answer to normal app searches.
                out = calc.concat(apps).concat(wins).concat(sys).concat(files).concat(clips)
                out.sort((a, b) => b.score - a.score)
                out = out.slice(0, 12)
                const web = SettingsState.searchWeb ? webP.search(parsed.rest) : []
                if (web.length) out = out.concat(web.slice(0, 1))
            }
        }
        results = out
    }

    // ── AI helpers exposed to Launcher ─────────────────────────
    function submitAi() {
        const parsed = _parseMode((query || "").trim())
        if (parsed.mode !== "ai" || !SettingsState.searchAi) return
        aiP.ask(parsed.rest)
    }
    function resetAi() { aiP.reset() }
    function cancelAi() { aiP.cancel() }
}
