import QtQuick
import Quickshell
import Quickshell.Io
import "../.."

// Niri windows — focus open windows by title or app_id.
Item {
    id: root
    visible: false

    readonly property string providerId: "window"
    readonly property string badge: "Window"

    Process { id: focusProc }

    function _focusWindow(id) {
        focusProc.command = ["niri", "msg", "action", "focus-window", "--id", String(id)]
        focusProc.running = true
    }

    function _toResult(w, score) {
        const title = w.title || w.app_id || "(untitled)"
        const sub = (w.app_id && w.title) ? w.app_id : ""
        return {
            providerId: providerId,
            icon: w.app_id ? Quickshell.iconPath(w.app_id, "application-x-executable") : "",
            iconText: w.app_id ? "" : "",
            title: title,
            subtitle: sub,
            badge: badge,
            score: score,
            onActivate: () => _focusWindow(w.id)
        }
    }

    function _scoreWindow(w, q) {
        const t = (w.title || "").toLowerCase()
        const a = (w.app_id || "").toLowerCase()
        if (t === q || a === q) return 850
        if (t.startsWith(q) || a.startsWith(q)) return 700
        if (t.includes(q) || a.includes(q)) return 500
        return 0
    }

    function search(query) {
        const wins = WMState.allWindows || []
        if (!query) return wins.slice(0, 8).map(w => _toResult(w, 200))
        const q = query.toLowerCase()
        const out = []
        for (const w of wins) {
            const s = _scoreWindow(w, q)
            if (s > 0) out.push(_toResult(w, s))
        }
        out.sort((x, y) => y.score - x.score)
        return out.slice(0, 10)
    }
}
