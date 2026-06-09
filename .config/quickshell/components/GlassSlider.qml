import QtQuick
import ".."
import "lib/sliderMath.js" as SliderMath

// Horizontal value slider. `value` and `max` are the model; drag/press emit
// moved(newValue). Track uses the content-accent track alpha; fill is accent.
Item {
    id: root
    property real value: 0.0
    property real max: 1.0
    property bool active: true          // false → muted look (textMuted fill)
    signal moved(real value)

    implicitHeight: 6
    implicitWidth: 120

    readonly property real _frac: SliderMath.frac(value, max)

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.sliderTrackAlpha)

        Rectangle {
            width: root._frac * parent.width
            height: parent.height
            radius: parent.radius
            color: root.active ? Colors.accent : Colors.textMuted
            Behavior on width { NumberAnimation { duration: Theme.durFast } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.SizeHorCursor
        function emitAt(px) { root.moved(SliderMath.valueAt(px, width, root.max)) }
        onPressed: ev => emitAt(ev.x)
        onPositionChanged: ev => { if (pressed) emitAt(ev.x) }
    }
}
