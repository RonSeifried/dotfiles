import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "."

Item {
    id: root
    required property LockContext context

    // Fade in on appear for smooth lock activation
    opacity: 0
    Component.onCompleted: opacity = 1
    Behavior on opacity {
        NumberAnimation { duration: LockTheme.durSlide; easing.type: Easing.OutCubic }
    }

    // Dim/tint overlay on top of compositor-blurred backdrop.
    // Background blur itself comes from ext-background-effect-v1 set on the
    // WlSessionLockSurface in shell.qml — niri blurs whatever it renders behind
    // the lock surface (wallpaper layer / backdrop-color).
    Rectangle {
        anchors.fill: parent
        color: LockColors.background
        opacity: LockColors.overlayAlpha
    }

    // Battery — top-right corner, hidden if no battery present
    BatteryWidget {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: LockTheme.batteryMargin
        anchors.rightMargin: LockTheme.batteryMargin
    }

    // Clock — vertically centered, offset above mid
    Clock {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: parent.height * LockTheme.clockOffsetY
    }

    // Password input — vertically centered, offset below mid
    PasswordPill {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: parent.height * LockTheme.inputOffsetY
        context: root.context
    }
}
