.pragma library

// Fill fraction [0,1] for a value against its max.
function frac(value, max) {
    if (max <= 0) return 0.0
    return Math.min(1.0, Math.max(0.0, value / max))
}

// Map a pointer x (px) on a track of `width` px to a value in [0, max].
// `max` lets callers model overshoot ranges (e.g. audio 0..1.5).
function valueAt(px, width, max) {
    if (width <= 0) return 0.0
    var f = Math.min(1.0, Math.max(0.0, px / width))
    return f * max
}
