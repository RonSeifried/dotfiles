import QtQuick
import QtQuick.Layouts
import "../"

// Conversation view for ai-mode. Replaces ResultList when engine.mode === "ai".
// Renders history bubbles + live streaming bubble; Text.MarkdownText for body.
Item {
    id: root

    property var aiProvider

    // ── Status strip (top) ───────────────────────────────────────
    Rectangle {
        id: status
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: visible ? statusText.implicitHeight + 10 : 0
        radius: Theme.radiusSmall
        visible: aiProvider && (aiProvider.streaming || aiProvider.error || aiProvider.keyMissing)
        color: {
            if (!aiProvider) return "transparent"
            if (aiProvider.error || aiProvider.keyMissing)
                return Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.18)
            return Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.15)
        }

        Text {
            id: statusText
            anchors {
                left: parent.left; right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 10; rightMargin: 10
            }
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.fontSmall
            font.family: Theme.fontFamily
            color: aiProvider && (aiProvider.error || aiProvider.keyMissing) ? Colors.error : Colors.accent
            text: {
                if (!aiProvider) return ""
                if (aiProvider.keyMissing) return aiProvider.keyError || "API key missing in ~/.askai-env"
                if (aiProvider.error)      return "Error: " + aiProvider.error
                if (aiProvider.streaming)  return "Generating with " + aiProvider.model + "…"
                return ""
            }
        }
    }

    // ── Conversation scroll ──────────────────────────────────────
    Flickable {
        id: scroll
        anchors {
            top: status.bottom; left: parent.left; right: parent.right; bottom: parent.bottom
            topMargin: status.visible ? Theme.spacingNormal : 0
        }
        contentWidth: width
        contentHeight: convoCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        ColumnLayout {
            id: convoCol
            width: scroll.width
            spacing: Theme.spacingNormal

            // Empty-state placeholder.
            Item {
                visible: aiProvider && aiProvider.history.length === 0
                    && !aiProvider.streaming && !aiProvider.error
                Layout.fillWidth: true
                Layout.preferredHeight: emptyText.implicitHeight + 24

                Text {
                    id: emptyText
                    anchors.centerIn: parent
                    width: parent.width - 24
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: Colors.textMuted
                    font.pixelSize: Theme.fontMedium
                    font.family: Theme.fontFamily
                    text: aiProvider && aiProvider.keyMissing
                        ? "Put GEMINI_API_KEY into ~/.askai-env to enable."
                        : "Ask anything — Enter to send, Esc to close."
                }
            }

            Repeater {
                model: aiProvider ? aiProvider.history : []
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: histBody.implicitHeight + 16
                    // Borderless bubbles: accent tint = user (state), neutral
                    // surface = assistant. No structural accent outlines.
                    radius: Theme.radiusMedium
                    color: modelData.role === "user"
                        ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.16)
                        : Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.55)

                    Text {
                        id: histBody
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                                  leftMargin: 10; rightMargin: 10 }
                        textFormat: Text.MarkdownText
                        wrapMode: Text.WordWrap
                        color: Colors.text
                        linkColor: Colors.accent
                        font.pixelSize: Theme.fontMedium
                        font.family: Theme.fontFamily
                        text: modelData.text
                        onLinkActivated: link => Qt.openUrlExternally(link)
                    }
                }
            }

            // Live streaming bubble (not yet in history).
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: streamBody.implicitHeight + 16
                visible: aiProvider && aiProvider.streaming && aiProvider.response.length > 0
                radius: Theme.radiusMedium
                color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.55)

                Text {
                    id: streamBody
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                              leftMargin: 10; rightMargin: 10 }
                    textFormat: Text.MarkdownText
                    wrapMode: Text.WordWrap
                    color: Colors.text
                    linkColor: Colors.accent
                    font.pixelSize: Theme.fontMedium
                    font.family: Theme.fontFamily
                    text: aiProvider ? aiProvider.response : ""
                }
            }
        }

        // Auto-scroll bottom as content grows.
        function scrollToBottom() {
            const max = Math.max(0, contentHeight - height)
            contentY = max
        }

        Connections {
            target: aiProvider
            ignoreUnknownSignals: true
            function onResponseUpdated() { Qt.callLater(scroll.scrollToBottom) }
            function onResponseDone()    { Qt.callLater(scroll.scrollToBottom) }
        }
    }
}
