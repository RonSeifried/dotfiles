pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property real luminance: 0.25
    property real complexity: 0.15
    property real density: 1.0
    property string source: ""
    FileView {
        path: (Quickshell.env("HOME") || "") + "/.cache/wal/wallpaper-analysis.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text())
                root.luminance = Number(d.luminance ?? 0.25)
                root.complexity = Number(d.complexity ?? 0.15)
                root.density = Math.max(0.88, Math.min(1.08, Number(d.density ?? 1)))
                root.source = d.source || ""
            } catch (e) { console.warn("WallpaperState: invalid analysis:", e) }
        }
    }
}
