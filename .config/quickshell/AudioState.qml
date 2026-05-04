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

    property string sinkName: sink?.description || sink?.name || "Audio"
    property string sourceName: source?.description || source?.name || "Microphone"

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
