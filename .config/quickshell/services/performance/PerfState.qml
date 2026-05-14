pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// PerfState — reactive store fed by ~/.config/scripts/perf-stat.sh.
//
// Lifecycle: the collector subprocess runs only while `active` is true
// (set externally by the shell when PerfPill or PerfPanel are visible).
// History ring-buffers are kept across pause/resume so re-opening the
// panel doesn't lose the rolling window.
//
// Generic naming + no Theme/Colors import on purpose — this module is
// services/-tier (phase-2 rshell split).
Singleton {
    id: root

    // ── Activation ───────────────────────────────────────────────
    property bool active: false

    // ── Sampling configuration ───────────────────────────────────
    readonly property int historySize: 60   // 60 samples ≈ 60 s at 1 Hz
    readonly property string scriptPath:
        (Quickshell.env("HOME") || "") + "/.config/scripts/perf-stat.sh"

    // ── Live values ──────────────────────────────────────────────
    property real cpuPercent: 0          // 0..1
    property var cpuPerCore: []          // [0..1, ...]
    property real memUsed: 0             // bytes
    property real memTotal: 0
    property real memPercent: 0          // 0..1 derived

    property var temps: []               // [{name, label, value(°C)}, ...]
    property string netIface: ""
    property real netRxKbps: 0
    property real netTxKbps: 0
    property real diskReadKbps: 0
    property real diskWriteKbps: 0

    // GPU — backend "nvidia"|"amd"|"intel"|"none"; null fields = unsupported.
    property string gpuBackend: "none"
    property string gpuName: ""
    property var gpuBusy: null           // 0..1 or null
    property var gpuMemUsed: null
    property var gpuMemTotal: null
    property var gpuTemp: null
    readonly property bool gpuPresent: gpuBackend !== "none"
    readonly property var gpuMemPercent:
        (gpuMemTotal && gpuMemTotal > 0 && gpuMemUsed !== null)
            ? gpuMemUsed / gpuMemTotal : null

    // ── History ring-buffers ─────────────────────────────────────
    property var cpuHistory: []
    property var memHistory: []
    property var gpuHistory: []
    property var netRxHistory: []
    property var netTxHistory: []
    property var diskReadHistory: []
    property var diskWriteHistory: []

    function _push(arr, v) {
        const out = arr.slice()
        out.push(v)
        if (out.length > historySize) out.shift()
        return out
    }

    // ── Process ──────────────────────────────────────────────────
    Process {
        id: collector
        running: root.active
        command: ["bash", root.scriptPath]
        onRunningChanged: {
            // bash exit (e.g. user mid-edit causes parse error) → restart
            // on next tick while still active.
            if (!running && root.active) Qt.callLater(() => running = true)
        }
        stdout: SplitParser {
            onRead: line => {
                if (!line) return
                let j
                try { j = JSON.parse(line) } catch (e) { return }

                root.cpuPercent  = j.cpu
                root.cpuPerCore  = j.cpuPerCore || []
                root.memUsed     = j.memUsed
                root.memTotal    = j.memTotal
                root.memPercent  = j.memTotal > 0 ? j.memUsed / j.memTotal : 0
                root.temps       = j.temps || []
                if (j.net) {
                    root.netIface  = j.net.iface || ""
                    root.netRxKbps = j.net.rxKbps || 0
                    root.netTxKbps = j.net.txKbps || 0
                }
                if (j.disk) {
                    root.diskReadKbps  = j.disk.readKbps || 0
                    root.diskWriteKbps = j.disk.writeKbps || 0
                }
                if (j.gpu) {
                    root.gpuBackend  = j.gpu.backend || "none"
                    root.gpuName     = j.gpu.name || ""
                    root.gpuBusy     = (j.gpu.busy === null) ? null : j.gpu.busy
                    root.gpuMemUsed  = (j.gpu.memUsed === null) ? null : j.gpu.memUsed
                    root.gpuMemTotal = (j.gpu.memTotal === null) ? null : j.gpu.memTotal
                    root.gpuTemp     = (j.gpu.temp === null) ? null : j.gpu.temp
                }

                root.cpuHistory       = root._push(root.cpuHistory, root.cpuPercent)
                root.memHistory       = root._push(root.memHistory, root.memPercent)
                root.gpuHistory       = root._push(root.gpuHistory, root.gpuBusy === null ? 0 : root.gpuBusy)
                root.netRxHistory     = root._push(root.netRxHistory, root.netRxKbps)
                root.netTxHistory     = root._push(root.netTxHistory, root.netTxKbps)
                root.diskReadHistory  = root._push(root.diskReadHistory, root.diskReadKbps)
                root.diskWriteHistory = root._push(root.diskWriteHistory, root.diskWriteKbps)
            }
        }
        // Drop stderr noise (parse errors during user edits etc).
        stderr: SplitParser { onRead: _ => {} }
    }

    // ── Helpers ──────────────────────────────────────────────────
    function formatKbps(v) {
        if (v < 1) return "0 KB/s"
        if (v < 1024) return v.toFixed(0) + " KB/s"
        return (v / 1024).toFixed(1) + " MB/s"
    }
    function formatBytes(b) {
        if (b === null || b === undefined) return "—"
        if (b < 1024) return b + " B"
        if (b < 1024 * 1024) return (b / 1024).toFixed(0) + " KB"
        if (b < 1024 * 1024 * 1024) return (b / 1024 / 1024).toFixed(0) + " MB"
        return (b / 1024 / 1024 / 1024).toFixed(1) + " GB"
    }
    // Take the hottest temp among 'sources' (substring-match on name).
    // Returns null if none found.
    function maxTemp(sources) {
        let best = null
        for (const t of root.temps) {
            for (const s of sources) {
                if (t.name.indexOf(s) !== -1) {
                    if (best === null || t.value > best) best = t.value
                }
            }
        }
        return best
    }
    readonly property var cpuTemp: maxTemp(["coretemp", "k10temp", "zenpower"])
}
