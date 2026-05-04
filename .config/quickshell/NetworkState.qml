pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Current connection state
    property bool wifiEnabled: false
    property string ssid: ""
    property int signal: 0                // 0-100
    property string connType: "none"      // "wifi" | "ethernet" | "none"
    property bool ethernetConnected: false

    // Network list for panel
    property var networks: []             // [{ssid, signal, security, active}]

    // VPN state
    property var vpns: []                 // [{name, type, active}]
    property bool anyVpnActive: vpns.some(v => v.active)

    // ── Event-driven: nmcli monitor emits line on every change ───
    Process {
        id: monitorProc
        running: true
        command: ["nmcli", "monitor"]
        // Auto-restart if nmcli monitor exits (NetworkManager restart, etc.)
        onRunningChanged: if (!running) running = true
        stdout: SplitParser {
            onRead: line => {
                // Throttle bursts: any line triggers a status refresh
                refreshDebounce.restart()
            }
        }
    }

    // Debounce rapid bursts (e.g. ifup emits several lines in <100ms)
    Timer {
        id: refreshDebounce
        interval: 250
        repeat: false
        onTriggered: { statusProc.running = true; root.refreshVpns() }
    }

    // Periodic safety net (signal-strength drift, missed events)
    Timer {
        interval: 30000; running: true; repeat: true
        onTriggered: { statusProc.running = true; root.refreshVpns() }
    }

    Process {
        id: statusProc
        running: true
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "dev", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.ethernetConnected = false
                root.ssid = ""
                root.connType = "none"

                const lines = text.trim().split("\n")
                for (const line of lines) {
                    const parts = line.split(":")
                    if (parts.length < 4) continue
                    const [device, type, state, conn] = parts
                    if (state !== "connected") continue
                    if (type === "wifi") {
                        root.connType = "wifi"
                        root.ssid = conn
                    } else if (type === "ethernet") {
                        root.connType = "ethernet"
                        root.ethernetConnected = true
                    }
                }
                wifiStateProc.running = true
            }
        }
    }

    Process {
        id: wifiStateProc
        command: ["nmcli", "-t", "-f", "WIFI", "g"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiEnabled = text.trim() === "enabled"
                if (root.connType === "wifi") signalProc.running = true
            }
        }
    }

    Process {
        id: signalProc
        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL", "dev", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.trim().split("\n")) {
                    const [inUse, sig] = line.split(":")
                    if (inUse === "*") {
                        root.signal = parseInt(sig) || 0
                        break
                    }
                }
            }
        }
    }

    // ── Load network list (on demand) ────────────────────────────
    Process {
        id: networkListProc
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {}
                const result = []
                for (const line of text.trim().split("\n")) {
                    if (!line) continue
                    // Format: IN-USE:SSID:SIGNAL:SECURITY
                    // SSID may contain colons — split from right
                    const firstColon = line.indexOf(":")
                    const rest = line.slice(firstColon + 1)
                    const lastColon2 = rest.lastIndexOf(":")
                    const rest2 = rest.slice(0, lastColon2)
                    const security = rest.slice(lastColon2 + 1)
                    const lastColon1 = rest2.lastIndexOf(":")
                    const ssid = rest2.slice(0, lastColon1)
                    const sig = parseInt(rest2.slice(lastColon1 + 1)) || 0
                    const active = line.startsWith("*")

                    if (!ssid) continue
                    if (!seen[ssid] || sig > seen[ssid].signal) {
                        seen[ssid] = { ssid, signal: sig, security: security.trim(), active }
                    }
                }
                result.push(...Object.values(seen).sort((a, b) => b.signal - a.signal))
                root.networks = result
            }
        }
    }

    function refreshNetworks() { networkListProc.running = true }

    // ── VPN management ───────────────────────────────────────────
    Process {
        id: vpnListProc
        running: true
        command: ["nmcli", "-t", "-f", "NAME,TYPE,STATE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const result = []
                const activeNames = new Set()
                // First pass: build active set from "connection show --active"
                for (const line of vpnListProc.activeListText.split("\n")) {
                    const p = line.split(":")
                    if (p.length >= 2 && (p[1] === "wireguard" || p[1] === "vpn"))
                        activeNames.add(p[0])
                }
                // Then list all VPNs
                for (const line of text.trim().split("\n")) {
                    const p = line.split(":")
                    if (p.length < 2) continue
                    if (p[1] !== "wireguard" && p[1] !== "vpn") continue
                    result.push({ name: p[0], type: p[1], active: activeNames.has(p[0]) })
                }
                root.vpns = result
            }
        }
        property string activeListText: ""
    }

    Process {
        id: vpnActiveProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show", "--active"]
        stdout: StdioCollector {
            onStreamFinished: {
                vpnListProc.activeListText = text
                vpnListProc.running = true
            }
        }
    }

    function refreshVpns() { vpnActiveProc.running = true }

    function toggleVpn(name, makeActive) {
        _runAction(["nmcli", "connection", makeActive ? "up" : "down", "id", name])
    }

    // ── Actions ──────────────────────────────────────────────────
    Process {
        id: actionProc
        stdout: StdioCollector {
            onStreamFinished: if (text.length > 0) console.log("[net out]", text.trim())
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.length > 0) console.warn("[net err]", text.trim())
        }
        onRunningChanged: if (!running) { statusProc.running = true; refreshVpns() }
    }

    function _runAction(args) {
        console.log("[net run]", args.join(" "))
        if (actionProc.running) actionProc.running = false
        actionProc.command = args
        actionProc.running = true
    }

    function toggleWifi() {
        _runAction(["nmcli", "radio", "wifi", root.wifiEnabled ? "off" : "on"])
    }

    function connectTo(ssid, password) {
        // Always use "device wifi connect": works for both saved and new networks
        const cmd = ["nmcli", "device", "wifi", "connect", ssid]
        if (password && password.length > 0) cmd.push("password", password)
        _runAction(cmd)
    }

    function disconnect() {
        // Find first connected device of current type and disconnect it by name
        _runAction(["bash", "-c",
            "dev=$(nmcli -t -f DEVICE,TYPE,STATE dev status | awk -F: '$3==\"connected\" && ($2==\"" +
            (connType === "wifi" ? "wifi" : "ethernet") +
            "\"){print $1; exit}'); [ -n \"$dev\" ] && nmcli device disconnect \"$dev\""
        ])
    }

    function rescan() {
        _runAction(["nmcli", "device", "wifi", "rescan"])
    }

    // Signal strength icon helper
    function signalIcon(s) {
        if (s >= 75) return "󰤨"
        if (s >= 50) return "󰤥"
        if (s >= 25) return "󰤢"
        return "󰤟"
    }
}
