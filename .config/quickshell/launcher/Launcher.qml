import QtQuick
import ".."
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property bool open: false

    visible: open
    color: "transparent"
    exclusiveZone: 0

    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.namespace: "qs-popup"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Native compositor blur (ext-background-effect-v1). launcherRect has
    // anchors-driven position + scale anim — Region.item binds via mapToScene,
    // scale-during-open is brief enough that polish-phase update is fine.
    BackgroundEffect.blurRegion: Region {
        item: launcherRect
        radius: Theme.radiusLarge
    }

    onOpenChanged: {
        if (open) {
            const pre = ControlState.launcherPrefill
            if (pre && pre.length > 0) {
                searchInput.text = pre
                ControlState.launcherPrefill = ""
                searchInput.cursorPosition = searchInput.text.length
            } else {
                searchInput.text = ""
            }
            searchInput.forceActiveFocus()
            openAnim.start()
        } else {
            // Abort in-flight stream on close; history persists for next open.
            engine.cancelAi()
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    function close() { closeAnim.start() }

    function _submitOrActivate() {
        if (engine.mode === "ai") {
            // Submit + clear input. Stay open. Response streams in AiView.
            engine.submitAi()
            searchInput.text = "ai "
            searchInput.cursorPosition = searchInput.text.length
        } else {
            resultList.activateCurrent()
        }
    }

    SearchEngine { id: engine; query: searchInput.text }

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: launcherRect; property: "opacity"; from: 0; to: 1; duration: Theme.durNormal; easing.type: Easing.OutQuad }
        NumberAnimation { target: launcherRect; property: "scale"; from: 0.95; to: 1; duration: Theme.durNormal; easing.type: Easing.OutQuad }
    }

    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: launcherRect; property: "opacity"; to: 0; duration: 150 }
            NumberAnimation { target: launcherRect; property: "scale"; to: 0.95; duration: 150 }
        }
        ScriptAction { script: { ControlState.launcherOpen = false; launcherRect.opacity = 1; launcherRect.scale = 1 } }
    }

    // Mode-aware placeholder + leading icon glyph.
    function modeIcon() {
        switch (engine.mode) {
            case "calc":   return ""
            case "system": return ""
            case "web":    return ""
            case "window": return "󰖯"
            case "files":  return ""
            case "pkg":    return ""
            case "ai":     return "󰚩"
            default:       return ""
        }
    }
    function modePlaceholder() {
        switch (engine.mode) {
            case "calc":   return "Calculate…  e.g. 2 + 2"
            case "system": return "System action…"
            case "web":    return "Search the web…"
            case "window": return "Focus window…"
            case "files":  return "Find files…"
            case "pkg":    return "Install package…  pacman + AUR"
            case "ai":     return "Ask AI…  Enter sends, Esc closes"
            default:       return "Search apps, type =  >  ?  w  f  p  ai …"
        }
    }

    Rectangle {
        id: launcherRect
        width: Theme.launcherWidth
        height: engine.mode === "ai"
            ? Theme.launcherMaxHeight
            : Math.min(
                searchBar.height + resultList.implicitHeight + hintBar.height
                    + Theme.panelPadding * 2 + Theme.spacingNormal * 2,
                Theme.launcherMaxHeight
              )
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Theme.launcherTopMargin }
        radius: Theme.radiusLarge
        color: Qt.rgba(Colors.bgVariant.r, Colors.bgVariant.g, Colors.bgVariant.b, Theme.elevation.e2TintAlpha)
        border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Theme.elevation.e1BorderAlpha)
        border.width: 1
        clip: true

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors {
                left: parent.left; right: parent.right
                top: parent.top; bottom: parent.bottom
                margins: Theme.panelPadding
            }
            spacing: Theme.spacingNormal

            // ── Search bar ───────────────────────────────────────
            Rectangle {
                id: searchBar
                Layout.fillWidth: true
                height: Theme.searchBarHeight
                radius: Theme.radiusPill
                color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.7)
                border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Theme.elevation.e1BorderAlpha)
                border.width: 1

                RowLayout {
                    anchors {
                        left: parent.left; right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: Theme.spacingLarge + 2
                        rightMargin: Theme.spacingLarge + 2
                    }
                    spacing: Theme.spacingNormal

                    Text {
                        text: root.modeIcon()
                        color: engine.mode === "default" ? Colors.textMuted : Colors.accent
                        font.pixelSize: Theme.fontLarge + 1
                        font.family: Theme.fontFamily

                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                    }

                    Item {
                        Layout.fillWidth: true
                        height: searchInput.height

                        Text {
                            anchors.fill: parent
                            text: root.modePlaceholder()
                            color: Colors.textMuted
                            font.pixelSize: Theme.fontLarge
                            font.family: Theme.fontFamily
                            visible: searchInput.text.length === 0
                            verticalAlignment: Text.AlignVCenter
                        }

                        TextInput {
                            id: searchInput
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                            color: Colors.text
                            font.pixelSize: Theme.fontLarge
                            font.family: Theme.fontFamily
                            clip: true

                            Keys.onEscapePressed: root.close()
                            Keys.onUpPressed: { if (engine.mode !== "ai") resultList.listViewAlias.decrementCurrentIndex() }
                            Keys.onDownPressed: { if (engine.mode !== "ai") resultList.listViewAlias.incrementCurrentIndex() }
                            Keys.onReturnPressed: root._submitOrActivate()
                            Keys.onEnterPressed:  root._submitOrActivate()
                        }
                    }

                    // Clear button when text present.
                    Text {
                        text: ""
                        color: Colors.textMuted
                        font.pixelSize: Theme.fontMedium
                        font.family: Theme.fontFamily
                        visible: searchInput.text.length > 0

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { searchInput.text = ""; searchInput.forceActiveFocus() }
                        }
                    }
                }
            }

            // ── Results / AI conversation ────────────────────────
            ResultList {
                id: resultList
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: engine.mode !== "ai"
                results: engine.results

                onActivated: r => {
                    if (!r) return
                    if (!r.keepOpen) root.close()
                }
            }

            AiView {
                id: aiView
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: engine.mode === "ai"
                aiProvider: engine.ai
            }

            // ── Hint bar ─────────────────────────────────────────
            Rectangle {
                id: hintBar
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.hintBarHeight
                color: "transparent"

                Rectangle {
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: 1
                    color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Colors.dividerAlpha)
                }

                RowLayout {
                    anchors {
                        left: parent.left; right: parent.right
                        verticalCenter: parent.verticalCenter
                        topMargin: 2
                    }
                    spacing: Theme.spacingNormal

                    Text {
                        text: engine.results.length + (engine.results.length === 1 ? " result" : " results")
                        color: Colors.textMuted
                        font.pixelSize: Theme.fontTiny + 1
                        font.family: Theme.fontFamily
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "= calc · > action · w win · f file · p pkg · ? web · ai chat"
                        color: Colors.textMuted
                        font.pixelSize: Theme.fontTiny + 1
                        font.family: Theme.fontFamily
                        visible: engine.mode === "default"
                    }

                    Text {
                        text: engine.modeHint
                        color: Colors.accent
                        font.pixelSize: Theme.fontTiny + 1
                        font.family: Theme.fontFamily
                        visible: engine.mode !== "default"
                    }

                    Text {
                        text: engine.mode === "ai" ? "↵ send · esc close" : "↑↓ ↵ esc"
                        color: Colors.textMuted
                        font.pixelSize: Theme.fontTiny + 1
                        font.family: Theme.fontFamily
                    }
                }
            }
        }
    }
}
