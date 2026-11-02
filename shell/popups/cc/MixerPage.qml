import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.services
import qs.components

// Outputs or inputs: which device is the default, and a slider per application
// playing through -- or recording from -- them.
ColumnLayout {
    id: root

    property bool output: true

    signal back

    readonly property var devices: output ? Audio.speakers : Audio.microphones
    readonly property var streams: output ? Audio.streams : Audio.recorders
    readonly property var current: output ? Audio.speaker : Audio.microphone

    spacing: 10

    PageHeader {
        title: root.output ? I18n.tr("Volume mixer") : I18n.tr("Input devices")
        onBack: root.back()
    }

    Scroller {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 420)
        spacing: 10

        ColumnLayout {
            width: parent.width
            spacing: 4

            Txt {
                text: root.output ? I18n.tr("Output") : I18n.tr("Input")
                dim: true
                em: 0.9
            }

            Repeater {
                model: root.devices

                DeviceRow {
                    required property var modelData

                    Layout.fillWidth: true
                    icon: root.output ? "audio-card-symbolic" : "audio-input-microphone-symbolic"
                    title: Audio.deviceName(modelData)
                    current: root.current === modelData
                    onClicked: {
                        if (root.output) Pipewire.preferredDefaultAudioSink = modelData
                        else Pipewire.preferredDefaultAudioSource = modelData
                    }
                }
            }
        }

        ColumnLayout {
            width: parent.width
            spacing: 10

            Txt {
                text: I18n.tr("Applications")
                dim: true
                em: 0.9
            }

            Txt {
                visible: root.streams.length === 0
                text: root.output ? I18n.tr("Nothing is playing") : I18n.tr("Nothing is recording")
                dim: true
            }

            Repeater {
                model: root.streams

                ColumnLayout {
                    id: stream

                    required property var modelData
                    readonly property var audio: modelData.audio

                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Icon {
                            name: Audio.streamIcon(stream.modelData)
                            fallback: "audio-x-generic-symbolic"
                        }

                        Txt {
                            Layout.fillWidth: true
                            text: Audio.streamName(stream.modelData)
                        }

                        IconButton {
                            icon: stream.audio?.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
                            active: stream.audio?.muted ?? false
                            tooltip: I18n.tr("Mute")
                            onClicked: if (stream.audio) stream.audio.muted = !stream.audio.muted
                        }
                    }

                    FatSlider {
                        Layout.fillWidth: true
                        value: stream.audio?.volume ?? 0
                        icon: stream.audio?.muted || (stream.audio?.volume ?? 0) <= 0 ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
                        onMoved: v => Audio.setVolume(stream.modelData, v)
                    }
                }
            }
        }
    }
}
