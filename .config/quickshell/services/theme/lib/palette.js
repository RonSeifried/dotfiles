// Shared colour math for BOTH qs instances (main shell + lock).
// The lock runs as its own `qs -p .../lock` and cannot import the main
// singletons — but plain JS imports are path-based, so this file is the
// single home for contrast/mix/signal logic (no more copied helpers).
.pragma library

// ── WCAG relative luminance / contrast ───────────────────────────
function lum(c) {
    function f(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
    return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b)
}

function ratio(a, b) {
    var la = lum(a), lb = lum(b)
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
}

// Nudge fg lightness until it clears `target` contrast against bg.
function ensureContrast(fg, bg, target) {
    if (ratio(fg, bg) >= target) return fg
    var step = lum(bg) < 0.5 ? 0.02 : -0.02
    var l = fg.hslLightness
    for (var i = 0; i < 60; ++i) {
        l += step
        if (l < 0 || l > 1) break
        var adj = Qt.hsla(fg.hslHue, fg.hslSaturation, l, fg.a)
        if (ratio(adj, bg) >= target) return adj
    }
    return fg
}

function mix(a, b, t) {
    return Qt.rgba(a.r * (1 - t) + b.r * t,
                   a.g * (1 - t) + b.g * t,
                   a.b * (1 - t) + b.b * t, 1)
}

// Wallpaper palettes are allowed to influence temperature, never to turn
// neutral chrome copy cyan/purple/green. `maxSaturation` preserves a whisper
// of the wallpaper while keeping surfaces and text visually neutral.
function neutralize(c, maxSaturation) {
    return Qt.hsla(c.hslHue, Math.min(c.hslSaturation, maxSaturation), c.hslLightness, c.a)
}

// ── Hue-aware signal colours ─────────────────────────────────────
// wallust's salience palette does not sort slots by hue, so "color1 = red"
// is not a given (a teal wallpaper yields brown/navy/purple in slots 1–3).
// A signal must stay semantic: pick the palette slot whose hue is closest
// to the anchor; if nothing in the palette is anywhere near the anchor hue,
// keep the palette's chroma character (S/L of the nearest slot) but force
// the anchor hue. Caller still runs ensureContrast on the result.
var HUE_ERROR   = 0 / 360        // red
var HUE_WARNING = 45 / 360       // amber
var HUE_SUCCESS = 130 / 360      // green
var _HUE_MAX_DIST = 35 / 360     // beyond this a slot no longer "reads as" the signal

function signalColor(slots, anchorHue) {
    var best = null, bestD = 1e9
    for (var i = 0; i < slots.length; ++i) {
        var c = slots[i]
        if (c.hslSaturation < 0.15) continue   // achromatic slots can't signal
        var d = Math.abs(c.hslHue - anchorHue)
        if (d > 0.5) d = 1 - d                 // circular hue distance
        if (d < bestD) { bestD = d; best = c }
    }
    // Direct slot only if it's close in hue AND chromatic enough to read as
    // a signal — a washed-out near-grey "amber" is worse than a synthesised one.
    if (best && bestD <= _HUE_MAX_DIST && best.hslSaturation >= 0.25) return best
    var s = best ? Math.min(0.85, Math.max(0.45, best.hslSaturation)) : 0.60
    var l = best ? Math.min(0.65, Math.max(0.45, best.hslLightness)) : 0.55
    return Qt.hsla(anchorHue, s, l, 1)
}

// ── Frost material constants ─────────────────────────────────────
// Single source for components/GlassSurface (frost mode) and the lock's
// frost widgets (PasswordPill, BatteryWidget) — replaces the "keep in
// sync" comment pairs.
var frost = {
    fill:      0.14,   // white wash fill
    border:    0.16,   // neutral white hairline
    highlight: 0.12,   // top-edge light
    pillFill:  0.12    // small chips (lock battery)
}
