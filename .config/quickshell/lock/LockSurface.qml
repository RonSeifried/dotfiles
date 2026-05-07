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

    // Clock — vertically centered, offset above mid
    Clock {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: parent.height * LockTheme.clockOffsetY
    }

    // Password input
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: parent.height * 0.15
        spacing: LockTheme.spacingLarge

        Rectangle {
            Layout.preferredWidth: LockTheme.inputWidth
            Layout.preferredHeight: LockTheme.inputHeight
            radius: LockTheme.radiusPill
            color: Qt.rgba(0, 0, 0, 0.55)
            border.color: passwordBox.activeFocus ? LockColors.accent : Qt.rgba(1, 1, 1, 0.18)
            border.width: LockTheme.inputBorder

            TextField {
                id: passwordBox
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                background: null
                color: LockColors.text
                placeholderText: "Password"
                placeholderTextColor: Qt.rgba(1, 1, 1, 0.4)
                font.family: LockTheme.fontFamily
                font.pointSize: LockTheme.fontInput
                verticalAlignment: TextInput.AlignVCenter
                focus: true
                enabled: !root.context.unlockInProgress
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhSensitiveData

                onTextChanged: root.context.currentText = text
                onAccepted: root.context.tryUnlock()

                Connections {
                    target: root.context
                    function onCurrentTextChanged() {
                        if (passwordBox.text !== root.context.currentText)
                            passwordBox.text = root.context.currentText
                    }
                }
            }
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            visible: root.context.showFailure
            text: "Wrong password"
            color: LockColors.error
            font.family: LockTheme.fontFamily
            font.pointSize: LockTheme.fontStatus
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            visible: root.context.unlockInProgress
            text: "Checking…"
            color: LockColors.textMuted
            font.family: LockTheme.fontFamily
            font.pointSize: LockTheme.fontStatus
        }
    }
}
