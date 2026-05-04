pragma Singleton
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Singleton {
    id: root

    // Pick first player that's actively playing, else first available
    property var active: {
        const players = Mpris.players?.values ?? []
        if (players.length === 0) return null
        const playing = players.find(p => p.playbackState === MprisPlaybackState.Playing)
        return playing ?? players[0]
    }

    property bool hasPlayer: active !== null
    property bool isPlaying: hasPlayer && active.playbackState === MprisPlaybackState.Playing
    property string title:  hasPlayer ? (active.trackTitle  ?? "") : ""
    property string artist: hasPlayer ? (active.trackArtist ?? "") : ""
    property string album:  hasPlayer ? (active.trackAlbum  ?? "") : ""

    function togglePlay() { if (hasPlayer && active.canTogglePlaying) active.togglePlaying() }
    function next()       { if (hasPlayer && active.canGoNext)       active.next() }
    function prev()       { if (hasPlayer && active.canGoPrevious)   active.previous() }
}
