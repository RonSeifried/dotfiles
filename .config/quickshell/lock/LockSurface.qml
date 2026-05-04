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

    color: "#1a1410"

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
        color: "#000000"
        opacity: 0.25
    }

    // Clock
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.18
        spacing: LockTheme.spacingNormal

        Label {
            id: clock
            property var date: new Date()
            anchors.horizontalCenter: parent.horizontalCenter
            renderType: Text.NativeRendering
            font.family: LockTheme.fontFamily
            font.pointSize: LockTheme.fontClock
            font.weight: Font.Light
            color: "#E5D7CE"
            text: {
                const h = date.getHours().toString().padStart(2, '0')
                const m = date.getMinutes().toString().padStart(2, '0')
                return `${h}:${m}`
            }
            Timer {
                running: true
                repeat: true
                interval: 1000
                onTriggered: clock.date = new Date()
            }
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: LockTheme.fontFamily
            font.pointSize: LockTheme.fontDate
            color: "#BEABC8"
            text: Qt.formatDate(clock.date, "dddd, d. MMMM yyyy")
        }
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
            border.color: passwordBox.activeFocus ? "#DB6FA6" : Qt.rgba(1, 1, 1, 0.18)
            border.width: LockTheme.inputBorder

            TextField {
                id: passwordBox
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                background: null
                color: "#E5D7CE"
                placeholderText: "Passwort"
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
            text: "Falsches Passwort"
            color: "#DB6FA6"
            font.family: LockTheme.fontFamily
            font.pointSize: LockTheme.fontStatus
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            visible: root.context.unlockInProgress
            text: "Prüfe …"
            color: "#BEABC8"
            font.family: LockTheme.fontFamily
            font.pointSize: LockTheme.fontStatus
        }
    }
}
