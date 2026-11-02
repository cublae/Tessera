pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// PipeWire, as far as the shell needs it.
//
// A node's volume and mute are only live while something tracks it, so every
// node the shell shows -- the default endpoints, the device lists, the
// application streams -- is bound through one tracker here.
//
// It also holds the volume ceiling. Neither PipeWire nor `wpctl` stops at 100%:
// a volume key held down runs on to 150%, which is software gain and sounds
// like it. The shell has no say in what sets the volume -- media keys go
// straight to WirePlumber -- so the limit is enforced after the fact, by
// watching the default output and pulling it back down. The guard is an
// inequality with some slack, so the corrective write, which notifies again,
// lands on the limit and finds nothing left to do.
Singleton {
    id: root

    readonly property PwNode speaker: Pipewire.defaultAudioSink
    readonly property PwNode microphone: Pipewire.defaultAudioSource

    readonly property var nodes: Pipewire.nodes.values

    // Hardware endpoints: the speakers and microphones a user picks between.
    readonly property var speakers: nodes.filter(n => n.type === PwNodeType.AudioSink)
    readonly property var microphones: nodes.filter(n => n.type === PwNodeType.AudioSource)

    // Application streams: who is playing, and who is recording.
    readonly property var streams: nodes.filter(n => n.type === PwNodeType.AudioOutStream)
    readonly property var inStreams: nodes.filter(n => n.type === PwNodeType.AudioInStream)

    // Filtered from a list that is tracked whole: the test reads properties, which
    // only a tracked node has, and filtering the tracked list itself would drop a
    // node, unbind it, and let it back in.
    readonly property var recorders: inStreams.filter(n => !root.isMonitor(n))

    // Absolute ceiling, whatever the config says. Above this it is only distortion.
    readonly property real hardMax: 1.5
    readonly property real maxVolume: Math.min(hardMax, Math.max(0, Config.c.audio.maxVolume))

    PwObjectTracker {
        objects: [root.speaker, root.microphone].concat(root.speakers, root.microphones, root.streams, root.inStreams)
            .filter(n => n)
    }

    // A capture of a sink's monitor is a mixer's peak meter or a recorder taking
    // the desktop audio -- not someone listening through the microphone.
    function isMonitor(node: PwNode): bool {
        const target = node.properties?.["stream.capture.sink"]
        return target === "true" || target === true
    }

    function streamName(node: PwNode): string {
        const props = node.properties ?? {}
        return props["application.name"] || node.description || node.nickname || node.name || I18n.tr("Unknown application")
    }

    function deviceName(node: PwNode): string {
        return node.description || node.nickname || node.name || I18n.tr("Unknown device")
    }

    function streamIcon(node: PwNode): string {
        const props = node.properties ?? {}
        return props["application.icon-name"] || props["application.process.binary"] || ""
    }

    function volumeIcon(volume: real, muted: bool): string {
        if (muted || volume <= 0) return "audio-volume-muted-symbolic"
        if (volume < 0.34) return "audio-volume-low-symbolic"
        if (volume < 0.67) return "audio-volume-medium-symbolic"
        return "audio-volume-high-symbolic"
    }

    function micIcon(volume: real, muted: bool): string {
        return muted || volume <= 0 ? "microphone-disabled-symbolic" : "audio-input-microphone-symbolic"
    }

    function setVolume(node: PwNode, value: real): void {
        if (!node?.audio) return
        node.audio.volume = Math.min(root.maxVolume, Math.max(0, value))
        if (node.audio.muted && value > 0) node.audio.muted = false
    }

    function enforce(): void {
        const audio = speaker?.audio
        if (audio && audio.volume > maxVolume + 0.0005) audio.volume = maxVolume
    }

    Connections {
        target: root.speaker?.audio ?? null
        function onVolumeChanged() {
            root.enforce()
        }
    }

    onMaxVolumeChanged: enforce()
    onSpeakerChanged: enforce()
}
