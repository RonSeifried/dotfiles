pragma Singleton
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Singleton {
    id: root

    // All known players (DBus snapshot). Used for tabs + presence.
    readonly property var players: Mpris.players?.values ?? []
    readonly property bool hasAny: players.length > 0

    // -1 = auto (prefer Playing, else first). >=0 = user-pinned index into players.
    // Pinned selection is dropped once that player disappears (clamped to auto).
    property int selectedIndex: -1

    readonly property var active: {
        const ps = players
        if (ps.length === 0) return null
        if (selectedIndex >= 0 && selectedIndex < ps.length) return ps[selectedIndex]
        const playing = ps.find(p => p.playbackState === MprisPlaybackState.Playing)
        return playing ?? ps[0]
    }

    readonly property bool hasPlayer: active !== null
    readonly property bool isPlaying: hasPlayer && active.playbackState === MprisPlaybackState.Playing
    readonly property string title:  hasPlayer ? (active.trackTitle  ?? "") : ""
    readonly property string artist: hasPlayer ? (active.trackArtist ?? "") : ""
    readonly property string album:  hasPlayer ? (active.trackAlbum  ?? "") : ""
    readonly property string art:    hasPlayer ? (active.trackArtUrl ?? "") : ""
    readonly property string identity: hasPlayer ? (active.identity ?? "") : ""

    readonly property real length:  hasPlayer ? (active.length ?? 0) : 0
    readonly property bool canSeek: hasPlayer && (active.canSeek === true)

    // Live position: MPRIS doesn't push position updates. Poll while playing.
    // pollTick changes each tick → position re-evaluates via active.position read.
    property real pollTick: 0
    readonly property real position: {
        pollTick // dep
        return hasPlayer ? (active.position ?? 0) : 0
    }
    Timer {
        interval: 500; repeat: true
        running: root.isPlaying
        onTriggered: root.pollTick = Date.now()
    }

    // Drop a stale pin if the targeted player vanished.
    onPlayersChanged: {
        if (selectedIndex >= players.length) selectedIndex = -1
    }

    function togglePlay() { if (hasPlayer && active.canTogglePlaying) active.togglePlaying() }
    function next()       { if (hasPlayer && active.canGoNext)       active.next() }
    function prev()       { if (hasPlayer && active.canGoPrevious)   active.previous() }
    function seek(sec)    { if (hasPlayer && active.canSeek) active.position = sec }
    function selectAuto() { selectedIndex = -1 }
    function selectAt(i)  { if (i >= 0 && i < players.length) selectedIndex = i }
}
