import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

Item {
    id: root
    required property LockContext context

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
            color: Qt.rgba(LockColors.surface.r, LockColors.surface.g, LockColors.surface.b, 0.55)
            border.width: LockTheme.inputBorder
            border.color: {
                if (root.context.authState === LockContext.Failed) return LockColors.error
                if (passwordBox.activeFocus) return LockColors.accent
                return Qt.rgba(1, 1, 1, 0.18)
            }
            Behavior on border.color { ColorAnimation { duration: LockTheme.durColor } }

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
