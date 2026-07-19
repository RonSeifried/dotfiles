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

    readonly property string _home: Quickshell.env("HOME") || ""
    readonly property string _scripts: _home + "/.config/scripts"
    readonly property string _wallCache: _home + "/.cache/current_wallpaper"
    readonly property string _lockShell: _home + "/.config/quickshell/lock"

    readonly property var _actions: [
        { title: "Lock Screen",        subtitle: "Lock the session",       glyph: "󰌾", action: () => _run("qs -p " + _lockShell + " ipc call lock lock") },
        { title: "Suspend",            subtitle: "Sleep system",            glyph: "󰒲", action: () => _run("systemctl suspend") },
        { title: "Reboot",             subtitle: "Restart system",          glyph: "󰜉", action: () => _run("systemctl reboot") },
        { title: "Shutdown",           subtitle: "Power off",               glyph: "󰐥", action: () => _run("systemctl poweroff") },
        { title: "Logout",             subtitle: "Exit niri session",       glyph: "󰍃", action: () => _run("niri msg action quit --skip-confirmation") },
        { title: "Power Menu",         subtitle: "Open power overlay",      glyph: "",  action: () => ControlState.toggleTransient("power") },
        { title: "Wallpaper Picker",   subtitle: "Change wallpaper",        glyph: "󰸉", action: () => ControlState.toggleTransient("wallpaper") },
        { title: "Clipboard History",  subtitle: "Past copied items",       glyph: "󰅍", action: () => ControlState.toggleTransient("clipboard") },
        { title: "Toggle Caffeine",    subtitle: "Inhibit idle/sleep",      glyph: "󰛊", action: () => ControlState.idleInhibited = !ControlState.idleInhibited },
        { title: "Notifications",      subtitle: "Open Control Center",     glyph: "󰂚", action: () => _run("qs ipc call control toggle") },
        { title: "Niri Overview",      subtitle: "Open workspace overview", glyph: "󰕮", action: () => _run("niri msg action toggle-overview") },
        { title: "Switch Audio Route", subtitle: "Choose speakers or microphone", glyph: "󰓃", action: () => ControlState.toggleTransient("audio") },
        { title: "Toggle Screen Recording", subtitle: "Start or stop region recording", glyph: "󰻃", action: () => _run(_scripts + "/screenrecord.sh") },
        { title: "Pick Color",         subtitle: "Sample a pixel → clipboard", glyph: "󰈋", action: () => _run(_scripts + "/pick-color.sh") },
        { title: "Ask AI",             subtitle: "Open Spotlight ai-mode",   glyph: "󰚩", action: () => _run("qs ipc call launcher ai") },
        { title: "Focus: Work",        subtitle: "Quiet, balanced, awake",   glyph: "󰢹", action: () => FocusState.apply("work") },
        { title: "Focus: Presentation", subtitle: "Bright, quiet, awake",    glyph: "󰐩", action: () => FocusState.apply("presentation") },
        { title: "Focus: Movie",       subtitle: "Dim, quiet, awake",        glyph: "󰿎", action: () => FocusState.apply("movie") },
        { title: "Focus: Wind Down",   subtitle: "Warm, dim, efficient",     glyph: "󰖔", action: () => FocusState.apply("winddown") },
        { title: "Focus: Off",         subtitle: "Restore normal desktop",   glyph: "󰅖", action: () => FocusState.apply("off") },
        { title: "Reload Colors",      subtitle: "Re-run wallust palette",  glyph: "󰏘", action: () => _run("wall=$(readlink -f \"" + _wallCache + "\" 2>/dev/null) && [ -f \"$wall\" ] && wallust run \"$wall\"") },
        { title: "Update System",      subtitle: "pacman + AUR via yay",    glyph: "󰚰", action: () => _run("kitty --class installer-pkg -e " + _scripts + "/installer/system-update.sh") },
        { title: "Desktop Settings",   subtitle: "Appearance, search and notifications", glyph: "󰒓", action: () => { ControlState.openControlCenter("settings") } },
        { title: "Desktop Health",     subtitle: "Check dependencies and generated state", glyph: "󰄬", action: () => _run("kitty --class=floating -e " + _scripts + "/dotfiles-doctor.sh") },
        { title: "Backup Dotfiles",    subtitle: "Create a recoverable local snapshot", glyph: "󰁯", action: () => _run(_scripts + "/dotfiles-backup.sh") },
        { title: "Nearby Share",       subtitle: "Send files or clipboard to another device", glyph: "󰒧", action: () => _run(_scripts + "/nearby-share.sh") },
        { title: "Remove Package",     subtitle: "fzf picker, multi-select", glyph: "󰮈", action: () => _run("kitty --class installer-pkg -e " + _scripts + "/installer/pkg-remove.sh") }
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
        const usageKey = "action:" + a.title
        return {
            providerId: providerId,
            icon: "",
            iconText: a.glyph,
            title: a.title,
            subtitle: a.subtitle,
            badge: badge,
            score: score + UsageState.score(usageKey),
            usageKey: usageKey,
            onActivate: () => { UsageState.record(usageKey); a.action() }
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
