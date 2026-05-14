import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../.."

PanelWindow {
    id: root

    property bool active: true

    readonly property var flow: PolkitState.flow
    readonly property bool hasFlow: flow !== null
    readonly property bool waiting: hasFlow && (!flow.isResponseRequired || flow.isCompleted)
    readonly property bool errored: hasFlow && flow.supplementaryIsError

    readonly property int cardWidth: 460
    readonly property int cardPadding: 22
    readonly property int iconCircle: 52
    readonly property int pillHeight: 46
    readonly property int btnHeight: 38

    visible: hasFlow && active
    color: "transparent"
    exclusiveZone: 0

    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.namespace: "qs-polkit"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    BackgroundEffect.blurRegion: Region {
        x: card.x
        y: card.y
        width: card.width
        height: card.height
        radius: Theme.radiusLarge
    }

    onHasFlowChanged: {
        if (hasFlow) {
            passwordField.text = ""
            backdrop.opacity = 0
            card.opacity = 0
            card.scale = 0.94
            openAnim.start()
            Qt.callLater(() => passwordField.forceActiveFocus())
        }
    }

    Connections {
        target: PolkitState.agent
        function onAuthenticationRequestStarted() {
            passwordField.text = ""
            Qt.callLater(() => passwordField.forceActiveFocus())
        }
    }

    Connections {
        target: root.flow
        ignoreUnknownSignals: true
        function onAuthenticationFailed() {
            shakeAnim.restart()
            passwordField.text = ""
            Qt.callLater(() => passwordField.forceActiveFocus())
        }
        function onIsResponseRequiredChanged() {
            if (root.flow && root.flow.isResponseRequired)
                Qt.callLater(() => passwordField.forceActiveFocus())
        }
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: backdrop; property: "opacity"; from: 0; to: 1; duration: Theme.durNormal; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: Theme.durNormal; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "scale"; from: 0.94; to: 1; duration: Theme.durSlide; easing.type: Easing.OutBack }
    }

    function submitPassword() {
        if (!root.hasFlow || !root.flow.isResponseRequired || root.flow.isCompleted) return
        root.flow.submit(passwordField.text)
    }

    function cancel() {
        if (root.hasFlow) root.flow.cancelAuthenticationRequest()
    }

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        opacity: 0
        MouseArea { anchors.fill: parent; onClicked: root.cancel() }
    }

    FocusScope {
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.cancel()
                event.accepted = true
            }
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: root.cardWidth
            height: contentColumn.implicitHeight + root.cardPadding * 2

            transform: Translate { id: shake; x: 0 }

            color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, 0.85)
            border.color: Qt.rgba(
                root.errored ? Colors.error.r : Colors.accent.r,
                root.errored ? Colors.error.g : Colors.accent.g,
                root.errored ? Colors.error.b : Colors.accent.b,
                0.45)
            border.width: 1
            radius: Theme.radiusLarge
            clip: true
            opacity: 0
            scale: 0.94

            Behavior on border.color { ColorAnimation { duration: Theme.durColor } }

            MouseArea { anchors.fill: parent }

            // Top accent bar — flips to error color on auth fail.
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 3
                color: root.errored ? Colors.error : Colors.accent
                Behavior on color { ColorAnimation { duration: Theme.durColor } }
            }

            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: shake; property: "x"; to: -12; duration: 70; easing.type: Easing.InOutQuad }
                NumberAnimation { target: shake; property: "x"; to:  12; duration: 70; easing.type: Easing.InOutQuad }
                NumberAnimation { target: shake; property: "x"; to:  -8; duration: 70; easing.type: Easing.InOutQuad }
                NumberAnimation { target: shake; property: "x"; to:   8; duration: 70; easing.type: Easing.InOutQuad }
                NumberAnimation { target: shake; property: "x"; to:  -4; duration: 70; easing.type: Easing.InOutQuad }
                NumberAnimation { target: shake; property: "x"; to:   0; duration: 70; easing.type: Easing.InOutQuad }
            }

            ColumnLayout {
                id: contentColumn
                anchors {
                    left: parent.left; right: parent.right; top: parent.top
                    leftMargin: root.cardPadding
                    rightMargin: root.cardPadding
                    topMargin: root.cardPadding
                }
                spacing: 18

                // ── Header: icon-circle + title stack ───────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Rectangle {
                        Layout.preferredWidth: root.iconCircle
                        Layout.preferredHeight: root.iconCircle
                        Layout.alignment: Qt.AlignTop
                        radius: width / 2
                        color: Qt.rgba(
                            root.errored ? Colors.error.r : Colors.accent.r,
                            root.errored ? Colors.error.g : Colors.accent.g,
                            root.errored ? Colors.error.b : Colors.accent.b,
                            0.15)
                        border.width: 1
                        border.color: Qt.rgba(
                            root.errored ? Colors.error.r : Colors.accent.r,
                            root.errored ? Colors.error.g : Colors.accent.g,
                            root.errored ? Colors.error.b : Colors.accent.b,
                            0.55)

                        Behavior on color { ColorAnimation { duration: Theme.durColor } }
                        Behavior on border.color { ColorAnimation { duration: Theme.durColor } }

                        Text {
                            anchors.centerIn: parent
                            text: root.errored ? "󰀦" : "󰦝"
                            color: root.errored ? Colors.error : Colors.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: 26
                            Behavior on color { ColorAnimation { duration: Theme.durColor } }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            text: "Authentication required"
                            color: Colors.text
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontLarge
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: root.hasFlow && root.flow.message ? root.flow.message : ""
                            color: Colors.textMuted
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSmall
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                    }
                }

                // ── Action ID badge ─────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    visible: root.hasFlow && root.flow.actionId !== ""
                    Layout.preferredHeight: actionIdLabel.implicitHeight + 12
                    radius: Theme.radiusSmall
                    color: Qt.rgba(Colors.bg.r, Colors.bg.g, Colors.bg.b, 0.4)
                    border.width: 1
                    border.color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.08)

                    Text {
                        id: actionIdLabel
                        anchors {
                            left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                            leftMargin: 12; rightMargin: 12
                        }
                        text: root.hasFlow ? root.flow.actionId : ""
                        color: Colors.textMuted
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontTiny
                        elide: Text.ElideMiddle
                    }
                }

                // ── Supplementary message (auth status) ─────────────
                Text {
                    Layout.fillWidth: true
                    visible: root.hasFlow && root.flow.supplementaryMessage !== ""
                    text: root.hasFlow ? root.flow.supplementaryMessage : ""
                    color: root.errored ? Colors.error : Colors.textMuted
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSmall
                    wrapMode: Text.WordWrap
                    Behavior on color { ColorAnimation { duration: Theme.durColor } }
                }

                // ── Password pill ───────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.pillHeight
                    radius: Theme.radiusPill
                    color: Qt.rgba(Colors.bg.r, Colors.bg.g, Colors.bg.b, 0.6)
                    border.width: 1.5
                    border.color: {
                        if (root.errored) return Colors.error
                        if (passwordField.activeFocus) return Colors.accent
                        return Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.18)
                    }
                    Behavior on border.color { ColorAnimation { duration: Theme.durColor } }

                    Text {
                        anchors {
                            left: parent.left; verticalCenter: parent.verticalCenter
                            leftMargin: 18
                        }
                        text: ""
                        color: passwordField.activeFocus ? Colors.accent : Colors.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                    }

                    TextField {
                        id: passwordField
                        anchors.fill: parent
                        anchors.leftMargin: 46
                        anchors.rightMargin: 18
                        background: null
                        color: Colors.text
                        placeholderText: root.hasFlow && root.flow.inputPrompt
                            ? root.flow.inputPrompt.replace(/:\s*$/, "")
                            : "Password"
                        placeholderTextColor: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.35)
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontMedium
                        verticalAlignment: TextInput.AlignVCenter
                        enabled: root.hasFlow && root.flow.isResponseRequired && !root.flow.isCompleted
                        echoMode: root.hasFlow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData
                        onAccepted: root.submitPassword()
                    }
                }

                // ── Buttons row ─────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Item { Layout.fillWidth: true }

                    // Cancel
                    Rectangle {
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: root.btnHeight
                        radius: Theme.radiusMedium
                        color: cancelHover.containsMouse
                            ? Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.10)
                            : "transparent"
                        border.color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.22)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: Colors.text
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontNormal
                        }

                        MouseArea {
                            id: cancelHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cancel()
                        }
                    }

                    // Authenticate (primary)
                    Rectangle {
                        Layout.preferredWidth: 130
                        Layout.preferredHeight: root.btnHeight
                        radius: Theme.radiusMedium
                        enabled: root.hasFlow && root.flow.isResponseRequired && !root.flow.isCompleted
                        opacity: enabled ? 1 : 0.45
                        color: authHover.containsMouse
                            ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 1.0)
                            : Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.85)
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                visible: !root.waiting
                                text: "󰍂"
                                color: Colors.bg
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                            }

                            Text {
                                text: root.waiting ? "Checking…" : "Authenticate"
                                color: Colors.bg
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontNormal
                                font.bold: true
                            }
                        }

                        MouseArea {
                            id: authHover
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: parent.enabled
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.submitPassword()
                        }
                    }
                }
            }
        }
    }
}
