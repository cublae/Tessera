import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.services
import qs.components

// What is playing: click to pause, scroll to change track.
//
// It follows whichever player is actually playing, and falls back to the first
// one, so pausing music to watch a video moves the module to the video.
Button {
    id: root

    property var bar

    readonly property var players: Mpris.players.values
    readonly property var player: players.find(p => p.isPlaying) ?? players[0] ?? null
    readonly property bool shown: player !== null

    tooltip: player ? ([player.trackArtist, player.trackTitle].filter(Boolean).join(" — ") || player.identity) : ""
    onClicked: if (player?.canTogglePlaying) player.togglePlaying()
    onScrolled: (dx, dy) => {
        if (!player) return
        if (dy < 0 && player.canGoNext) player.next()
        else if (dy > 0 && player.canGoPrevious) player.previous()
    }

    Icon {
        name: root.player?.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
    }

    Txt {
        id: title

        visible: !root.bar.vertical
        text: root.player ? (root.player.trackTitle || root.player.identity) : ""
        Layout.preferredWidth: Math.min(implicitWidth, fontMetrics.averageCharacterWidth * Math.max(6, Config.c.media.maxLength))

        FontMetrics {
            id: fontMetrics

            font: title.font
        }
    }
}
