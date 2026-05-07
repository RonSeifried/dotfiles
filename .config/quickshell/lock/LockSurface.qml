import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "."

Rectangle {
    id: root
    required property LockContext context

    color: LockColors.background

    // Fade in on appear for smooth lock activation
    opacity: 0
    Component.onCompleted: opacity = 1
    Behavior on opacity {
        NumberAnimation { duration: LockTheme.durSlide; easing.type: Easing.OutCubic }
    }

    // Wallpaper source (hidden — blurred copy is rendered below)
    Image {
        id: wallpaper
        anchors.fill: parent
        source: "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
        fillMode: Image.PreserveAspectCrop
        smooth: true
        asynchronous: true
        cache: true
        visible: false
    }

    // Blurred wallpaper
    MultiEffect {
        anchors.fill: wallpaper
        source: wallpaper
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        blurMultiplier: 1.5
        brightness: -0.15
        saturation: -0.1
    }

    // Subtle dark overlay for readability
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
