.pragma library

// Current/max → fraction [0,1].
function frac(cur, max) {
    if (max <= 0) return 0.0
    return Math.min(1.0, Math.max(0.0, cur / max))
}

// Clamp a target fraction to the safe range [0.05, 1] (avoid a black screen).
function clampFrac(f) {
    return Math.min(1.0, Math.max(0.05, f))
}

// Fraction → integer percent for `brightnessctl set <pct>%`.
function pct(frac) {
    return Math.round(clampFrac(frac) * 100)
}
