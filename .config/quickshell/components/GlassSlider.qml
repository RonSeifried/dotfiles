import QtQuick
import ".."
import "lib/sliderMath.js" as SliderMath

// Horizontal value slider: a quiet 8px groove and precise 16px thumb. Its
// pointer target remains 26px tall. `value`/`max` are the model;
// drag/press emit moved(newValue).
Item {
    id: root
    property real value: 0.0
    property real max: 1.0
    property bool active: true          // false → dimmed (muted) look
    property string accessibleName: "Value"
    signal moved(real value)
    signal dragFinished()

    implicitHeight: 26
    implicitWidth: 120
    activeFocusOnTab: true
    Accessible.role: Accessible.Slider
    Accessible.name: accessibleName
    Keys.onLeftPressed: root.moved(Math.max(0, root.value - root.max * 0.05))
    Keys.onRightPressed: root.moved(Math.min(root.max, root.value + root.max * 0.05))

    readonly property real _frac: SliderMath.frac(value, max)
    readonly property real _knob: 16

    Rectangle {
        id: track
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 8
        radius: height / 2
        color: Qt.rgba(1, 1, 1, Theme.ink.track)
        clip: true

        // Active fill — a brighter groove from the left to the knob centre.
        Rectangle {
            height: parent.height
            width: knob.x + knob.width / 2
            radius: parent.radius
            color: root.active ? Colors.accent : Qt.rgba(1, 1, 1, Theme.ink.dim)
            Behavior on width { NumberAnimation { duration: Theme.durFast } }
        }
    }

    // Neutral thumb with a fine dark keyline; it stays legible on any accent.
    Rectangle {
        id: knob
        width: root._knob; height: root._knob; radius: height / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root._frac * (root.width - root._knob)
        color: "white"
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.12)
        Behavior on x { NumberAnimation { duration: Theme.durFast } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.SizeHorCursor
        function emitAt(px) { root.moved(SliderMath.valueAt(px, width, root.max)) }
        onPressed: ev => emitAt(ev.x)
        onPositionChanged: ev => { if (pressed) emitAt(ev.x) }
        onReleased: root.dragFinished()
    }

    Rectangle {
        anchors.fill: parent; anchors.margins: -3
        radius: height / 2; color: "transparent"
        border.width: root.activeFocus ? 2 : 0
        border.color: Qt.rgba(1, 1, 1, 0.72)
    }
}
