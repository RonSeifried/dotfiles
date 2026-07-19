import QtQuick
import ".."
import "../components"
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property bool open: false
    property var searchHistory: []
    property int historyIndex: -1

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

    // A restrained scrim separates Spotlight from busy terminal/editor content
    // without making the desktop feel modal or theatrical.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.18)
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
            const q = searchInput.text.trim()
            if (q.length && (searchHistory.length === 0 || searchHistory[0] !== q))
                searchHistory = [q].concat(searchHistory).slice(0, 30)
            historyIndex = -1
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
            NumberAnimation { target: launcherRect; property: "opacity"; to: 0; duration: Theme.durFast }
            NumberAnimation { target: launcherRect; property: "scale"; to: 0.95; duration: Theme.durFast }
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
            default:       return "Search apps, files, actions, windows and the web…"
        }
    }
    function resultScopes() {
        const labels = [], seen = ({})
        for (const r of engine.results) {
            const label = r.badge || "Result"
            if (!seen[label]) { seen[label] = true; labels.push(label) }
        }
        return labels.join("  ·  ")
    }

    Rectangle {
        id: launcherRect
        width: Math.min(engine.mode === "ai" ? Theme.launcherWidth : 680,
            Math.max(Theme.launcherMinWidth, root.width - 2 * Theme.spacingXL))
        height: engine.mode === "ai"
            ? Theme.launcherMaxHeight
            : Math.min(
                searchBar.height
                    + Math.max(resultList.implicitHeight,
                        resultList.selectedResult && resultList.selectedResult.path ? 238 : 0)
                    + hintBar.height
                    + Theme.panelPadding * 2 + Theme.spacingNormal * 2,
                Theme.launcherMaxHeight
              )
        anchors {
            horizontalCenter: parent.horizontalCenter; top: parent.top
            topMargin: Math.max(48, Math.min(Theme.launcherTopMargin, root.height * 0.12))
        }
        radius: Theme.radiusXL
        color: "transparent"
        clip: true

        // Shared glass material (floating modal — all corners, full border).
        GlassSurface {
            anchors.fill: parent
            level: "e3"
            radius: Theme.radiusXL
        }

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
                // No field box at all (macOS Spotlight): the search row sits
                // directly on the panel glass with a divider below. A nested
                // rectangle (opaque OR translucent) always showed seams at its
                // rounded corners — removing it kills the artifact entirely.
                color: "transparent"

                // Divider under the search row, separating it from the results.
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 1
                    color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, Colors.dividerAlpha)
                }

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
                        font.family: Theme.fontIcon

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
                            Keys.onUpPressed: {
                                if (engine.mode === "ai") return
                                if (searchInput.text.length === 0 && root.searchHistory.length) {
                                    root.historyIndex = Math.min(root.searchHistory.length - 1, root.historyIndex + 1)
                                    searchInput.text = root.searchHistory[root.historyIndex]
                                    searchInput.cursorPosition = searchInput.text.length
                                } else resultList.listViewAlias.decrementCurrentIndex()
                            }
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
                        font.family: Theme.fontIcon
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
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: engine.mode !== "ai"
                spacing: Theme.spacingNormal

                ResultList {
                    id: resultList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    results: engine.results

                    onActivated: r => {
                        if (!r) return
                        if (!r.keepOpen) root.close()
                    }
                }

                PreviewPane {
                    Layout.preferredWidth: 220
                    Layout.fillHeight: true
                    visible: !!(resultList.selectedResult && resultList.selectedResult.path)
                    result: resultList.selectedResult
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
                    color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, Colors.dividerAlpha)
                }

                RowLayout {
                    anchors {
                        left: parent.left; right: parent.right
                        verticalCenter: parent.verticalCenter
                        topMargin: 2
                    }
                    spacing: Theme.spacingNormal

                    Text {
                        text: engine.mode === "ai" ? "Conversation"
                            : engine.results.length + (engine.results.length === 1 ? " result" : " results")
                        color: Colors.textMuted
                        font.pixelSize: Theme.fontTiny + 1
                        font.family: Theme.fontFamily
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: root.resultScopes()
                        color: Colors.textMuted
                        font.pixelSize: Theme.fontTiny + 1
                        font.family: Theme.fontFamily
                        visible: engine.mode === "default" && searchInput.text.length > 0
                    }

                    Text {
                        text: "?  Web   ·   =  Calculate   ·   ai  Chat"
                        color: Colors.textMuted
                        font.pixelSize: Theme.fontTiny + 1
                        font.family: Theme.fontFamily
                        visible: engine.mode === "default" && searchInput.text.length === 0
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
