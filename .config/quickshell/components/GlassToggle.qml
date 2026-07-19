import QtQuick
import ".."

// On/off switch. Track recolors to accent when on; knob slides.
// `checked` is a plain binding — the toggle never self-assigns, it only
// emits `toggled(value)`; the consumer flips the backend and the binding
// moves the knob. Keeps external state (CC tile, ipc) in sync.
Item {
    id: root
    property bool checked: false
    property string accessibleName: "Toggle"
    signal toggled(bool value)

    implicitWidth: 44
    implicitHeight: 24
    activeFocusOnTab: true
    Accessible.role: Accessible.CheckBox
    Accessible.name: accessibleName
    Accessible.checkable: true
    Accessible.checked: checked
    Keys.onReturnPressed: root.toggled(!root.checked)
    Keys.onEnterPressed: root.toggled(!root.checked)
    Keys.onSpacePressed: root.toggled(!root.checked)

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.checked
            ? Colors.accent
            : Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, Theme.elevation.e1TintAlpha)
        Behavior on color { ColorAnimation { duration: Theme.durNormal } }

        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.leftMargin: parent.radius; anchors.rightMargin: parent.radius
            height: 1
            color: Qt.rgba(1, 1, 1, Theme.elevation.e1HighlightAlpha)
        }
    }

    Rectangle {
        id: knob
        width: parent.height - 6; height: width
        radius: height / 2
        y: 3
        x: root.checked ? parent.width - width - 3 : 3
        color: root.checked ? Colors.bg : Colors.text
        Behavior on x { NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Theme.durNormal } }
    }

    TapHandler {
        onTapped: root.toggled(!root.checked)
    }

    Rectangle {
        anchors.fill: parent; anchors.margins: -3
        radius: height / 2; color: "transparent"
        border.width: root.activeFocus ? 2 : 0
        border.color: Qt.rgba(1, 1, 1, 0.72)
    }
}
