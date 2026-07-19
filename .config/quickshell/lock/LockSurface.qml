import QtQuick
import QtQuick.Effects
import Quickshell
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

    // ── Backdrop: blurred wallpaper + neutral scrim (macOS lock) ──
    // The surface is created fresh on every lock, so cache:false picks up
    // wallpaper changes without a watcher. Falls back to a dark palette
    // gradient when the symlink is missing/unreadable.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.darker(LockColors.background, 1.1) }
            GradientStop { position: 1.0; color: Qt.darker(LockColors.background, 1.6) }
        }
    }

    Image {
        id: wallpaper
        anchors.fill: parent
        visible: false // rendered through the blur effect below
        source: "file://" + (Quickshell.env("HOME") || "") + "/.cache/current_wallpaper"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        // Cap decode size to the surface — wallpapers can be far larger
        // than the screen and would make the blur needlessly expensive.
        sourceSize.width: Math.max(64, root.width)
    }

    MultiEffect {
        anchors.fill: wallpaper
        source: wallpaper
        visible: wallpaper.status === Image.Ready
        blurEnabled: true
        blur: LockTheme.blurAmount
        blurMax: LockTheme.blurMax
        autoPaddingEnabled: false
    }

    // Neutral scrim — deliberately black, not a palette colour, so the
    // wallpaper's own tones stay true (palette tint here read as "dirty").
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, LockTheme.scrimAlpha)
    }

    // ── Content ──────────────────────────────────────────────────

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
