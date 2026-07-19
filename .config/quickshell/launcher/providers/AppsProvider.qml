import QtQuick
import Quickshell
import "../.."

// Apps provider — desktop entries.
// Result: { providerId, icon, title, subtitle, badge, score, onActivate }
Item {
    id: root
    visible: false

    readonly property string providerId: "apps"
    readonly property string badge: "App"
    readonly property int defaultLimit: 20
    readonly property int filterLimit: 12

    function _allApps() {
        const out = []
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay) continue
            out.push(e)
        }
        return out.sort((a, b) => a.name.localeCompare(b.name))
    }

    function _toResult(app, score) {
        const usageKey = "app:" + (app.id || app.name)
        return {
            providerId: providerId,
            icon: app.icon ? Quickshell.iconPath(app.icon, "application-x-executable") : "",
            iconText: "",
            title: app.name,
            subtitle: app.genericName || app.comment || "",
            badge: badge,
            score: score + UsageState.score(usageKey),
            usageKey: usageKey,
            onActivate: () => { UsageState.record(usageKey); app.execute() }
        }
    }

    function _scoreApp(app, q) {
        const name = (app.name || "").toLowerCase()
        const generic = (app.genericName || "").toLowerCase()
        const comment = (app.comment || "").toLowerCase()
        const kws = (app.keywords || []).map(k => k.toLowerCase())

        if (name === q) return 1000
        if (name.startsWith(q)) return 800
        if (name.includes(q)) return 600
        if (generic.startsWith(q)) return 500
        if (generic.includes(q)) return 400
        if (kws.some(k => k === q)) return 380
        if (kws.some(k => k.startsWith(q))) return 350
        if (kws.some(k => k.includes(q))) return 300
        if (comment.includes(q)) return 200
        return 0
    }

    function search(query) {
        const all = _allApps()
        if (!query) {
            const recent = all.map(a => _toResult(a, 100))
            recent.sort((a, b) => b.score - a.score || a.title.localeCompare(b.title))
            return recent.slice(0, defaultLimit)
        }
        const q = query.toLowerCase()
        const scored = []
        for (const app of all) {
            const s = _scoreApp(app, q)
            if (s > 0) scored.push(_toResult(app, s))
        }
        scored.sort((a, b) => b.score - a.score)
        return scored.slice(0, filterLimit)
    }
}
