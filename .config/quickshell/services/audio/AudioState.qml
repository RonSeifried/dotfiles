pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    // Bind sink + source so audio.volume / muted become available
    PwObjectTracker {
        objects: [
            Pipewire.defaultAudioSink,
            Pipewire.defaultAudioSource
        ]
    }

    property var sink: Pipewire.defaultAudioSink
    property var source: Pipewire.defaultAudioSource

    property bool sinkReady: Pipewire.ready && sink !== null && sink.ready && sink.audio !== null
    property bool sourceReady: Pipewire.ready && source !== null && source.ready && source.audio !== null

    property real volume: sinkReady ? sink.audio.volume : 0
    property bool muted: sinkReady ? sink.audio.muted : false
    property real micVolume: sourceReady ? source.audio.volume : 0
    property bool micMuted: sourceReady ? source.audio.muted : false

    property string sinkName: sink ? (sink.description || sink.name || "Audio") : "Audio"
    property string sourceName: source ? (source.description || source.name || "Microphone") : "Microphone"

    // ── Output device switching ──────────────────────────────────
    // All real output devices (hardware sinks, not per-app streams).
    readonly property var sinks: {
        const out = []
        for (const n of Pipewire.nodes.values)
            if (n && n.isSink && !n.isStream) out.push(n)
        return out
    }
    readonly property var sources: {
        const out = []
        for (const n of Pipewire.nodes.values)
            if (n && n.isSource && !n.isStream) out.push(n)
        return out
    }
    // Track them so .description / .ready populate for the picker.
    PwObjectTracker { objects: root.sinks.concat(root.sources) }

    // Short human label for a sink. One ALSA card can expose several nodes
    // whose `description` all start with the same chipset blurb ("500 Series
    // Chipset Family …") — node.nick ("Speaker", "HDMI 3") is the part that
    // actually distinguishes them.
    function sinkLabel(n) {
        if (!n) return "Output"
        return n.nickname || n.description || n.name || "Output"
    }

    function setSink(node) {
        if (node) Pipewire.preferredDefaultAudioSink = node
    }

    function sourceLabel(n) {
        if (!n) return "Input"
        return n.nickname || n.description || n.name || "Input"
    }
    function setSource(node) {
        if (node) Pipewire.preferredDefaultAudioSource = node
    }

    function setVolume(v) {
        if (!sinkReady) return
        sink.audio.volume = Math.max(0, Math.min(1.5, v))
    }

    function toggleMute() {
        if (!sinkReady) return
        sink.audio.muted = !sink.audio.muted
    }

    function setMicVolume(v) {
        if (!sourceReady) return
        source.audio.volume = Math.max(0, Math.min(1.0, v))
    }

    function toggleMicMute() {
        if (!sourceReady) return
        source.audio.muted = !source.audio.muted
    }
}
