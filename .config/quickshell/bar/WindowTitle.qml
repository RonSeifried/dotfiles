import QtQuick
import ".."
import Quickshell.Wayland

Text {
    // ToplevelManager is instant via Wayland protocol — no polling lag
    property string title: ToplevelManager.activeToplevel?.title ?? ""

    text: title || "Desktop"
    color: title ? Colors.text : Colors.textMuted
    font.pixelSize: Theme.fontMedium
    font.family: Theme.fontFamily
    elide: Text.ElideRight
    maximumLineCount: 1

    Behavior on color { ColorAnimation { duration: Theme.durFast } }
}
