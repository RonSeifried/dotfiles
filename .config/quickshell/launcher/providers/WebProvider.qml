import QtQuick
import Quickshell
import Quickshell.Io

// Web search fallback — opens DuckDuckGo via xdg-open.
Item {
    id: root
    visible: false

    readonly property string providerId: "web"
    readonly property string badge: "Web"
    readonly property string searchUrl: "https://duckduckgo.com/?q="

    Process { id: openProc }

    function _openUrl(url) {
        openProc.command = ["xdg-open", url]
        openProc.running = true
    }

    function _isUrl(q) {
        return /^(https?:\/\/|www\.)/i.test(q) || /^[a-z0-9.\-]+\.[a-z]{2,}(\/.*)?$/i.test(q)
    }

    function search(query) {
        const q = (query || "").trim()
        if (!q) return []

        // Direct URL → open as-is.
        if (_isUrl(q)) {
            const url = /^https?:\/\//i.test(q) ? q : "https://" + q
            return [{
                providerId: providerId,
                icon: "",
                iconText: "󰖟",
                title: "Open " + q,
                subtitle: url,
                badge: badge,
                score: 700,
                onActivate: () => _openUrl(url)
            }]
        }

        return [{
            providerId: providerId,
            icon: "",
            iconText: "",
            title: "Search the web for " + q,
            subtitle: "DuckDuckGo",
            badge: badge,
            score: 50,
            onActivate: () => _openUrl(searchUrl + encodeURIComponent(q))
        }]
    }
}
