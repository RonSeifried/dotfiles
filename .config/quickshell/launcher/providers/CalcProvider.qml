import QtQuick
import Quickshell
import Quickshell.Io

// Calculator — sandboxed JS-eval, regex-whitelisted input.
// Result: copies value to clipboard via wl-copy on Enter.
Item {
    id: root
    visible: false

    readonly property string providerId: "calc"
    readonly property string badge: "="

    Process { id: copyProc }

    function _format(n) {
        if (typeof n !== "number" || !isFinite(n)) return null
        if (Math.abs(n) < 1e-12) return "0"
        if (Number.isInteger(n) && Math.abs(n) < 1e15) return n.toString()
        const abs = Math.abs(n)
        if (abs > 1e12 || abs < 1e-4) return n.toExponential(6)
        return parseFloat(n.toFixed(10)).toString()
    }

    function _copy(text) {
        copyProc.command = ["sh", "-c", "printf %s " + JSON.stringify(text) + " | wl-copy"]
        copyProc.running = true
    }

    function _evalExpr(raw) {
        const t = raw.trim()
        if (!t || !/[0-9]/.test(t)) return null
        // Whitelist: digits, basic ops, parens, dot, comma, percent, caret, whitespace.
        if (!/^[\s0-9+\-*/().,%^]+$/.test(t)) return null
        try {
            const expr = t.replace(/\^/g, "**").replace(/,/g, ".")
            const r = Function('"use strict"; return (' + expr + ')')()
            return _format(r)
        } catch (e) {
            return null
        }
    }

    function search(query) {
        const result = _evalExpr(query)
        if (result === null) return []
        return [{
            providerId: providerId,
            icon: "",
            iconText: "",
            title: "= " + result,
            subtitle: "Enter to copy",
            badge: badge,
            score: 950,
            onActivate: () => _copy(result),
            keepOpen: false
        }]
    }
}
