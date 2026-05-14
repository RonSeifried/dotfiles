pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// VPN-only state (qs 0.3 Networking module doesn't expose VPN connections).
// Listens on `nmcli monitor` and lists wireguard/openvpn connections.
Singleton {
    id: root

    property var vpns: []                 // [{name, type, active}]
    property bool anyVpnActive: vpns.some(v => v.active)

    // ── nmcli monitor (with backoff to avoid respawn storm) ──────
    Process {
        id: monitorProc
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser { onRead: _ => refreshDebounce.restart() }
        onExited: monitorRestart.restart()
    }
    Timer {
        id: monitorRestart
        interval: 2000   // backoff: don't respawn faster than 2s
        repeat: false
        onTriggered: if (!monitorProc.running) monitorProc.running = true
    }

    Timer {
        id: refreshDebounce
        interval: 250; repeat: false
        onTriggered: root.refresh()
    }

    // Periodic safety refresh (cheap, ignored if monitor is healthy).
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.refresh() }

    // ── Single-call list with STATE column ───────────────────────
    Process {
        id: listProc
        running: true
        command: ["nmcli", "-t", "-f", "NAME,TYPE,STATE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const result = []
                for (const line of text.trim().split("\n")) {
                    const p = line.split(":")
                    if (p.length < 3) continue
                    if (p[1] !== "wireguard" && p[1] !== "vpn") continue
                    result.push({ name: p[0], type: p[1], active: p[2] === "activated" })
                }
                root.vpns = result
            }
        }
    }

    function refresh() { listProc.running = true }

    // ── Toggle ───────────────────────────────────────────────────
    Process {
        id: actionProc
        stderr: StdioCollector {
            onStreamFinished: if (text.length > 0) console.warn("[vpn err]", text.trim())
        }
        onRunningChanged: if (!running) root.refresh()
    }

    function toggleVpn(name, makeActive) {
        if (actionProc.running) actionProc.running = false
        actionProc.command = ["nmcli", "connection", makeActive ? "up" : "down", "id", name]
        actionProc.running = true
    }
}
