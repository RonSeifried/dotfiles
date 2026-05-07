import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../.."

// System actions — power, locks, toggles, panels.
Item {
    id: root
    visible: false

    readonly property string providerId: "system"
    readonly property string badge: "Action"

    Process { id: execProc }

    function _run(cmd) {
        execProc.command = ["sh", "-c", cmd]
        execProc.running = true
    }

    readonly property var _actions: [
        { title: "Lock Screen",        subtitle: "Lock the session",       glyph: "󰌾", action: () => _run("qs -p ~/.config/quickshell/lock ipc call lock lock") },
        { title: "Suspend",            subtitle: "Sleep system",            glyph: "󰒲", action: () => _run("systemctl suspend") },
        { title: "Reboot",             subtitle: "Restart system",          glyph: "󰜉", action: () => _run("systemctl reboot") },
        { title: "Shutdown",           subtitle: "Power off",               glyph: "󰐥", action: () => _run("systemctl poweroff") },
        { title: "Logout",             subtitle: "Exit niri session",       glyph: "󰍃", action: () => _run("niri msg action quit --skip-confirmation") },
        { title: "Power Menu",         subtitle: "Open power overlay",      glyph: "",  action: () => ControlState.powerMenuOpen = true },
        { title: "Wallpaper Picker",   subtitle: "Change wallpaper",        glyph: "󰸉", action: () => ControlState.wallpaperPickerOpen = true },
        { title: "Clipboard History",  subtitle: "Past copied items",       glyph: "󰅍", action: () => ControlState.clipboardOpen = true },
        { title: "Toggle Caffeine",    subtitle: "Inhibit idle/sleep",      glyph: "󰛊", action: () => ControlState.idleInhibited = !ControlState.idleInhibited },
        { title: "Toggle Notifications", subtitle: "Show notification panel", glyph: "󰂚", action: () => ControlState.togglePanel("notif") },
        { title: "Niri Overview",      subtitle: "Open workspace overview", glyph: "󰕮", action: () => _run("niri msg action toggle-overview") },
        { title: "Reload Colors",      subtitle: "Re-run wallust palette",  glyph: "󰏘", action: () => _run("wallust run \"$(cat ~/.cache/current_wallpaper 2>/dev/null || echo)\" 2>/dev/null") },
        { title: "Update System",      subtitle: "pacman + AUR via yay",    glyph: "󰚰", action: () => _run("kitty --class installer-pkg -e ~/.config/scripts/installer/system-update.sh") },
        { title: "Remove Package",     subtitle: "fzf picker, multi-select", glyph: "󰮈", action: () => _run("kitty --class installer-pkg -e ~/.config/scripts/installer/pkg-remove.sh") }
    ]

    function _scoreAction(a, q) {
        const t = a.title.toLowerCase()
        const s = a.subtitle.toLowerCase()
        if (t === q) return 900
        if (t.startsWith(q)) return 750
        if (t.includes(q)) return 550
        if (s.includes(q)) return 350
        // word-boundary match in title (e.g. "lock" matches "Lock Screen")
        if (t.split(/\s+/).some(w => w.startsWith(q))) return 700
        return 0
    }

    function _toResult(a, score) {
        return {
            providerId: providerId,
            icon: "",
            iconText: a.glyph,
            title: a.title,
            subtitle: a.subtitle,
            badge: badge,
            score: score,
            onActivate: a.action
        }
    }

    function search(query) {
        if (!query) {
            // No empty default — system actions only show when typed.
            return []
        }
        const q = query.toLowerCase()
        const out = []
        for (const a of _actions) {
            const s = _scoreAction(a, q)
            if (s > 0) out.push(_toResult(a, s))
        }
        out.sort((x, y) => y.score - x.score)
        return out
    }

    // Force-list (for "> " prefix mode): show all even on empty query.
    function listAll() {
        return _actions.map(a => _toResult(a, 500))
    }
}
