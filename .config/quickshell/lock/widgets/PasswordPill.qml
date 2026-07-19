import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

Item {
    id: root
    required property LockContext context

    // Caps-lock heuristic: Wayland exposes no direct LED state to QML, but a
    // typed letter betrays it (uppercase without Shift / lowercase with).
    // Key_CapsLock presses toggle it from there on.
    property bool capsOn: false

    implicitWidth: LockTheme.inputWidth
    implicitHeight: column.implicitHeight

    transform: Translate { id: shake; x: 0 }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: shake; property: "x"; to: -LockTheme.shakeAmplitude; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shake; property: "x"; to:  LockTheme.shakeAmplitude; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shake; property: "x"; to: -LockTheme.shakeAmplitude * 0.75; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shake; property: "x"; to:  LockTheme.shakeAmplitude * 0.75; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shake; property: "x"; to: -LockTheme.shakeAmplitude * 0.375; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shake; property: "x"; to:  0; duration: 70; easing.type: Easing.InOutQuad }
    }

    Connections {
        target: root.context
        function onAuthStateChanged() {
            if (root.context.authState === LockContext.Failed) shakeAnim.restart()
        }
    }

    ColumnLayout {
        id: column
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        spacing: LockTheme.spacingLarge

        Rectangle {
            id: pill
            Layout.preferredWidth: LockTheme.inputWidth
            Layout.preferredHeight: LockTheme.inputHeight
            radius: LockTheme.radiusPill
            // Frost material (mirrors GlassSurface.frost): white wash fill,
            // neutral hairline idle → accent on focus → error on failure.
            color: Qt.rgba(1, 1, 1, LockTheme.frostFillAlpha)
            border.width: LockTheme.inputBorder
            border.color: {
                if (root.context.authState === LockContext.Failed) return LockColors.error
                if (passwordBox.activeFocus) return LockColors.accent
                return Qt.rgba(1, 1, 1, LockTheme.frostBorderAlpha)
            }
            Behavior on border.color { ColorAnimation { duration: LockTheme.durColor } }

            // Top-edge white highlight ("light from above"), inset past the
            // capsule's corner arcs like GlassSurface does.
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                anchors.leftMargin: parent.height / 2
                anchors.rightMargin: parent.height / 2
                anchors.topMargin: 1
                height: 1
                color: Qt.rgba(1, 1, 1, LockTheme.frostHighlightAlpha)
            }

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
                enabled: root.context.authState !== LockContext.Authenticating
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhSensitiveData

                onTextChanged: root.context.currentText = text
                onAccepted: root.context.tryUnlock()

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_CapsLock) {
                        root.capsOn = !root.capsOn
                        return
                    }
                    const t = event.text
                    if (t.length !== 1) return
                    const upper = t >= "A" && t <= "Z"
                    const lower = t >= "a" && t <= "z"
                    if (!upper && !lower) return
                    const shift = (event.modifiers & Qt.ShiftModifier) !== 0
                    root.capsOn = (upper && !shift) || (lower && shift)
                }

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
            // Caps lock is a STATE, not an error — muted, like the OSD's mute.
            Layout.alignment: Qt.AlignHCenter
            visible: root.capsOn
            text: "⇪  Caps Lock"
            color: LockColors.textMuted
            font.family: LockTheme.fontFamily
            font.pointSize: LockTheme.fontStatus
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            visible: root.context.authState === LockContext.Failed && root.context.statusText !== ""
            text: root.context.statusText
            color: LockColors.error
            font.family: LockTheme.fontFamily
            font.pointSize: LockTheme.fontStatus
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            visible: root.context.authState === LockContext.Authenticating
            text: "Checking…"
            color: LockColors.textMuted
            font.family: LockTheme.fontFamily
            font.pointSize: LockTheme.fontStatus
        }
    }
}
