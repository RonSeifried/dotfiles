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

    function _conversion(raw) {
        const m = raw.trim().toLowerCase().match(/^(-?[0-9]+(?:[.,][0-9]+)?)\s*([a-z°]+)\s+(?:in|to)\s+([a-z°]+)$/)
        if (!m) return null
        const value = parseFloat(m[1].replace(",", ".")), from = m[2], to = m[3]
        const aliases = { meters:"m", meter:"m", kilometres:"km", kilometers:"km", feet:"ft", foot:"ft", inches:"in", inch:"in", miles:"mi", grams:"g", gram:"g", kilograms:"kg", pounds:"lb", pound:"lb", ounces:"oz", celsius:"c", fahrenheit:"f", kelvin:"k", bytes:"b", kilobytes:"kb", megabytes:"mb", gigabytes:"gb" }
        const f = aliases[from] || from, t = aliases[to] || to
        if (["c","°c","f","°f","k"].includes(f) && ["c","°c","f","°f","k"].includes(t)) {
            const c = f === "f" || f === "°f" ? (value - 32) * 5/9 : f === "k" ? value - 273.15 : value
            return _format(t === "f" || t === "°f" ? c * 9/5 + 32 : t === "k" ? c + 273.15 : c) + " " + t.toUpperCase()
        }
        const factors = { mm:0.001, cm:0.01, m:1, km:1000, in:0.0254, ft:0.3048, yd:0.9144, mi:1609.344,
            mg:0.000001, g:0.001, kg:1, oz:0.028349523125, lb:0.45359237,
            b:1, kb:1024, mb:1048576, gb:1073741824, tb:1099511627776 }
        if (factors[f] === undefined || factors[t] === undefined) return null
        // Do not cross dimensions merely because both use numeric factors.
        const dimension = u => ["mm","cm","m","km","in","ft","yd","mi"].includes(u) ? 1
            : ["mg","g","kg","oz","lb"].includes(u) ? 2 : 3
        if (dimension(f) !== dimension(t)) return null
        return _format(value * factors[f] / factors[t]) + " " + t
    }

    function search(query) {
        const conversion = _conversion(query)
        if (conversion !== null) return [{
            providerId, icon: "", iconText: "󰦨", title: conversion,
            subtitle: "Converted · Enter to copy", badge: "Convert", score: 980,
            onActivate: () => _copy(conversion), keepOpen: false
        }]
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
