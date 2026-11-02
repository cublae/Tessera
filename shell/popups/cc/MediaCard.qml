import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.services
import qs.components

// What is playing, over its cover art.
Rectangle {
    id: root

    readonly property var player: Mpris.players.values[0] ?? null

    visible: player !== null
    Layout.fillWidth: true
    Layout.preferredHeight: 120
    radius: Theme.radiusLg
    color: Theme.cardBg
    clip: true

    function clock(seconds: real): string {
        if (!Number.isFinite(seconds) || seconds < 0) return "0:00"
        const total = Math.floor(seconds)
        return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, "0")}`
    }

    // MPRIS does not push the position; it has to be asked for.
    Timer {
        running: root.visible && (root.player?.isPlaying ?? false)
        repeat: true
        interval: 1000
        onTriggered: root.player.positionChanged()
    }

    Image {
        anchors.fill: parent
        source: root.player?.trackArtUrl ?? ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 400
    }

    // Keeps the text readable over any picture.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.25) }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.7) }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 0

        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: 6

            Icon {
                name: Icons.appIcon(root.player?.desktopEntry ?? "")
                size: 14
            }

            Txt {
                text: root.player?.identity ?? ""
                color: "white"
                em: 0.85
            }
        }

        Item {
            Layout.fillHeight: true
        }

        RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Txt {
                    Layout.fillWidth: true
                    text: root.player?.trackTitle || I18n.tr("Unknown track")
                    color: "white"
                    font.weight: Font.Bold
                }

                Txt {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.player?.trackArtist ?? ""
                    color: "white"
                    opacity: 0.85
                }

                Txt {
                    text: {
                        const p = root.player
                        if (!p) return ""
                        return p.length > 0 ? `${root.clock(p.position)} / ${root.clock(p.length)}` : root.clock(p.position)
                    }
                    color: "white"
                    opacity: 0.75
                    em: 0.8
                    font.features: { "tnum": 1 }
                }
            }

            IconButton {
                icon: "media-skip-backward-symbolic"
                iconColor: "white"
                hoverColor: Qt.rgba(1, 1, 1, 0.15)
                enabled: root.player?.canGoPrevious ?? false
                onClicked: root.player.previous()
            }

            IconButton {
                icon: root.player?.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                iconColor: "white"
                hoverColor: Qt.rgba(1, 1, 1, 0.15)
                onClicked: root.player.togglePlaying()
            }

            IconButton {
                icon: "media-skip-forward-symbolic"
                iconColor: "white"
                hoverColor: Qt.rgba(1, 1, 1, 0.15)
                enabled: root.player?.canGoNext ?? false
                onClicked: root.player.next()
            }
        }
    }
}
