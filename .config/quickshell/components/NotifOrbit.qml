import QtQuick
import ".."

// Travelling highlight around the CC icon's rounded-rectangle contour. This
// keeps the original comet language without involving QtQuick.Shape, whose
// renderer leaked diagonal segments across resizing layer-shell windows.
Item {
    id: root
    property color lineColor: Colors.accentAlt
    property bool running: true
    property real phase: 0
    property real radius: Theme.radiusSmall

    onPhaseChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.Image
        antialiasing: true

        function pointAt(t) {
            const inset = 1.2
            const left = inset, top = inset
            const right = width - inset, bottom = height - inset
            const r = Math.max(1, Math.min(root.radius, (bottom - top) / 2))
            const straightX = Math.max(0, right - left - 2 * r)
            const straightY = Math.max(0, bottom - top - 2 * r)
            const arc = Math.PI * r / 2
            const perimeter = 2 * straightX + 2 * straightY + 4 * arc
            let d = ((t % 1) + 1) % 1 * perimeter

            if (d < straightX) return Qt.point(left + r + d, top)
            d -= straightX
            if (d < arc) { const a = -Math.PI / 2 + d / r; return Qt.point(right - r + Math.cos(a) * r, top + r + Math.sin(a) * r) }
            d -= arc
            if (d < straightY) return Qt.point(right, top + r + d)
            d -= straightY
            if (d < arc) { const a = d / r; return Qt.point(right - r + Math.cos(a) * r, bottom - r + Math.sin(a) * r) }
            d -= arc
            if (d < straightX) return Qt.point(right - r - d, bottom)
            d -= straightX
            if (d < arc) { const a = Math.PI / 2 + d / r; return Qt.point(left + r + Math.cos(a) * r, bottom - r + Math.sin(a) * r) }
            d -= arc
            if (d < straightY) return Qt.point(left, bottom - r - d)
            d -= straightY
            const a = Math.PI + d / r
            return Qt.point(left + r + Math.cos(a) * r, top + r + Math.sin(a) * r)
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.lineWidth = 1.55
            ctx.lineCap = "round"
            const segments = 88
            for (let i = 0; i < segments; ++i) {
                const p0 = pointAt(i / segments)
                const p1 = pointAt((i + 1) / segments)
                const distance = ((i / segments - root.phase) % 1 + 1) % 1
                const alpha = 0.12 + 0.84 * Math.pow(1 - distance, 3.2)
                ctx.strokeStyle = Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b, alpha)
                ctx.beginPath(); ctx.moveTo(p0.x, p0.y); ctx.lineTo(p1.x, p1.y); ctx.stroke()
            }
        }
    }

    NumberAnimation on phase {
        running: root.running && root.visible && Theme.motionEnabled
        from: 0; to: 1; duration: 2600; loops: Animation.Infinite
    }
}
