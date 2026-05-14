pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Io

// WM-agnostic state surface. Today: niri-backend only.
// Future: alternate backends (hyprland/sway) implement the same property+function
// shape so consumers stay unchanged when an additional WM is added.
Singleton {
    id: root

    // ── Public interface (WM-agnostic) ───────────────────────────
    property var workspaces: []
    property int activeWorkspaceId: -1
    property string focusedOutput: ""
    property string focusedWindowTitle: ""
    property var allWindows: []

    function focusWorkspace(id) {
        focusProc.command = ["niri", "msg", "action", "focus-workspace-by-id", String(id)]
        focusProc.running = true
    }

    // ── Niri backend (private impl) ──────────────────────────────
    function _applyWorkspaces(ws) {
        root.workspaces = ws.sort((a, b) => a.idx - b.idx)
        const active = ws.find(w => w.is_focused)
        if (active) {
            root.activeWorkspaceId = active.id
            if (active.output) root.focusedOutput = active.output
        }
    }

    Process {
        id: initWs
        command: ["niri", "msg", "--json", "workspaces"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                try {
                    const ws = JSON.parse(line)
                    root._applyWorkspaces(ws)
                } catch (e) {}
            }
        }
    }

    Process {
        id: initWin
        command: ["niri", "msg", "--json", "windows"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                try {
                    const wins = JSON.parse(line)
                    root.allWindows = wins
                    const focused = wins.find(w => w.is_focused)
                    root.focusedWindowTitle = focused ? (focused.title || focused.app_id || "") : ""
                } catch (e) {}
            }
        }
    }

    Process {
        id: eventStream
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        onRunningChanged: if (!running) running = true
        stdout: SplitParser {
            onRead: line => {
                try {
                    const ev = JSON.parse(line)
                    const type = Object.keys(ev)[0]

                    if (type === "WorkspacesChanged") {
                        root._applyWorkspaces(ev.WorkspacesChanged.workspaces)
                    } else if (type === "WorkspaceActivated") {
                        if (ev.WorkspaceActivated.focused) {
                            const wid = ev.WorkspaceActivated.id
                            root.activeWorkspaceId = wid
                            const w = root.workspaces.find(x => x.id === wid)
                            if (w && w.output) root.focusedOutput = w.output
                        }
                    } else if (type === "WindowsChanged") {
                        root.allWindows = ev.WindowsChanged.windows || []
                        const f = root.allWindows.find(w => w.is_focused)
                        if (f) root.focusedWindowTitle = f.title || f.app_id || ""
                    } else if (type === "WindowOpenedOrChanged") {
                        const win = ev.WindowOpenedOrChanged.window
                        if (win.is_focused)
                            root.focusedWindowTitle = win.title || win.app_id || ""
                        const idx = root.allWindows.findIndex(w => w.id === win.id)
                        const next = root.allWindows.slice()
                        if (idx >= 0) next[idx] = win; else next.push(win)
                        root.allWindows = next
                    } else if (type === "WindowFocusChanged") {
                        const winId = ev.WindowFocusChanged.id
                        const w = root.allWindows.find(x => x.id === winId)
                        root.focusedWindowTitle = w ? (w.title || w.app_id || "") : ""
                    } else if (type === "WindowClosed") {
                        const cid = ev.WindowClosed.id
                        root.allWindows = root.allWindows.filter(w => w.id !== cid)
                        initWin.running = true
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: focusProc
    }
}
