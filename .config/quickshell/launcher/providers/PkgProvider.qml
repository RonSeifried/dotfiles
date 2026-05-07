import QtQuick
import Quickshell
import Quickshell.Io

// Package provider — pacman repos + AUR (yay).
// Lazy-fetches lists on first use, filters in-memory.
// Activate → kitty terminal runs `yay -S <pkg>` (handles repo + AUR + sudo).
Item {
    id: root
    visible: false

    readonly property string providerId: "pkg"
    readonly property int filterLimit: 12

    property var _repoList: []     // pacman -Slq
    property var _aurList: []      // yay -Slaq
    property var _installed: ({})  // map: name → true

    property bool _repoReady: false
    property bool _aurReady: false
    property bool _installedReady: false

    readonly property bool ready: _repoReady && _aurReady && _installedReady

    // ── Process collectors ──────────────────────────────────────
    Process {
        id: pacmanProc
        command: ["pacman", "-Slq"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root._repoList = text.split("\n").filter(s => s.length > 0)
                root._repoReady = true
            }
        }
    }

    Process {
        id: yayProc
        command: ["yay", "-Slaq"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root._aurList = text.split("\n").filter(s => s.length > 0)
                root._aurReady = true
            }
        }
    }

    Process {
        id: installedProc
        command: ["pacman", "-Qq"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {}
                for (const line of text.split("\n")) {
                    if (line) map[line] = true
                }
                root._installed = map
                root._installedReady = true
            }
        }
    }

    Process { id: launchProc }

    function _ensureLoaded() {
        if (!_repoReady && !pacmanProc.running) pacmanProc.running = true
        if (!_aurReady && !yayProc.running) yayProc.running = true
        if (!_installedReady && !installedProc.running) installedProc.running = true
    }

    function _install(pkg) {
        // yay handles repo + AUR + sudo. Keep terminal open after to show errors / done.
        const cmd = "yay -S '" + pkg.replace(/'/g, "'\\''") + "'; echo; read -p 'Press enter to close'"
        launchProc.command = ["kitty", "--class", "installer-pkg", "-e", "sh", "-c", cmd]
        launchProc.running = true
    }

    function _score(name, q) {
        const n = name.toLowerCase()
        if (n === q) return 1000
        if (n.startsWith(q)) return 800
        if (n.includes("-" + q) || n.includes("_" + q)) return 600
        if (n.includes(q)) return 500
        return 0
    }

    function _toResult(name, source, score) {
        const installed = !!_installed[name]
        return {
            providerId: providerId,
            icon: "",
            iconText: source === "aur" ? "" : "",
            title: name,
            subtitle: installed ? "Installed · re-install" : (source === "aur" ? "AUR package" : "Official repository"),
            badge: source === "aur" ? "AUR" : "Repo",
            score: score + (installed ? -50 : 0),
            onActivate: () => _install(name)
        }
    }

    function search(query) {
        _ensureLoaded()

        if (!ready) {
            return [{
                providerId: providerId,
                icon: "", iconText: "󱂐",
                title: "Loading package list…",
                subtitle: "pacman + AUR (one-shot, cached for session)",
                badge: "Pkg",
                score: 0,
                onActivate: () => {}
            }]
        }

        if (!query) {
            return [{
                providerId: providerId,
                icon: "", iconText: "",
                title: "Type a package name…",
                subtitle: _repoList.length + " repo · " + _aurList.length + " AUR",
                badge: "Pkg",
                score: 0,
                onActivate: () => {}
            }]
        }

        const q = query.toLowerCase()
        const out = []

        for (let i = 0; i < _repoList.length; i++) {
            const s = _score(_repoList[i], q)
            if (s > 0) out.push(_toResult(_repoList[i], "repo", s))
        }
        for (let i = 0; i < _aurList.length; i++) {
            const s = _score(_aurList[i], q)
            if (s > 0) out.push(_toResult(_aurList[i], "aur", s))
        }

        out.sort((a, b) => b.score - a.score)
        return out.slice(0, filterLimit)
    }
}
