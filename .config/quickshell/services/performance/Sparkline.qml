import QtQuick
import QtQuick.Shapes

// Area-filled sparkline. Pure-Shapes (GPU-accelerated, anti-aliased).
//
// Usage:
//   Sparkline { values: [0.1, 0.4, ...]; maxValue: 1.0; strokeColor: ...; fillColor: ... }
//
// Generic services/-tier — no Theme/Colors import; caller passes colors.
Item {
    id: root

    // Input data.
    property var values: []                 // numeric array, ordered oldest→newest
    property real maxValue: 1.0             // y-axis ceiling; auto-fit if autoScale.
    property bool autoScale: false          // if true, maxValue derived from values
    property real minMax: 0.01              // floor on auto-scaled max (avoid div0)

    // Style. Callers pass palette colors (PerfPill/PerfCard bind Colors.accent*);
    // the default is neutral white ink, NOT a palette hex — this tier stays
    // framework-pure and the shell never shows an off-palette colour.
    property color strokeColor: "white"
    property color fillColor:   Qt.rgba(strokeColor.r, strokeColor.g, strokeColor.b, 0.25)
    property real strokeWidth: 1.5
    property bool showFill: true

    // Effective max.
    readonly property real _effMax: {
        if (!autoScale) return Math.max(maxValue, 1e-6)
        let m = 0
        for (const v of values) if (v > m) m = v
        return Math.max(m, minMax)
    }

    Shape {
        id: shape
        anchors.fill: parent
        antialiasing: true
        // GeometryRenderer is less fancy but stable across the layer-shell and
        // popup textures used by this shell; CurveRenderer caused cross-window
        // path corruption on this GPU.
        preferredRendererType: Shape.GeometryRenderer

        // Fill area.
        ShapePath {
            id: fillPath
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: root.showFill ? root.fillColor : "transparent"

            // Start from bottom-left.
            startX: 0; startY: root.height

            PathPolyline {
                path: {
                    const n = root.values.length
                    if (n < 2) return [Qt.point(0, root.height), Qt.point(root.width, root.height)]
                    const max = root._effMax
                    const pts = [Qt.point(0, root.height)]
                    for (let i = 0; i < n; ++i) {
                        const x = (i / (n - 1)) * root.width
                        const y = root.height - Math.min(1, root.values[i] / max) * root.height
                        pts.push(Qt.point(x, y))
                    }
                    pts.push(Qt.point(root.width, root.height))
                    return pts
                }
            }
        }

        // Stroke line.
        ShapePath {
            id: linePath
            strokeColor: root.strokeColor
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            startX: 0
            startY: root.values.length > 0
                ? root.height - Math.min(1, root.values[0] / root._effMax) * root.height
                : root.height

            PathPolyline {
                path: {
                    const n = root.values.length
                    if (n < 2) return []
                    const max = root._effMax
                    const pts = []
                    for (let i = 0; i < n; ++i) {
                        const x = (i / (n - 1)) * root.width
                        const y = root.height - Math.min(1, root.values[i] / max) * root.height
                        pts.push(Qt.point(x, y))
                    }
                    return pts
                }
            }
        }
    }
}
