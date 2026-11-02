import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// Recording settings, where you are when you reach for them.
//
// The choices land in the state directory, on top of the config; the undo
// button drops them all and goes back to what the config says.
ColumnLayout {
    id: root

    signal back

    spacing: 10

    PageHeader {
        title: I18n.tr("Screen Record")
        onBack: root.back()

        IconButton {
            visible: Recorder.overridden
            icon: "edit-undo-symbolic"
            tooltip: I18n.tr("Back to the configured settings")
            onClicked: Recorder.reset()
        }
    }

    Choices {
        title: I18n.tr("Capture")
        current: Recorder.settings.target
        options: [
            { value: "portal", label: I18n.tr("Ask") },
            { value: "focused", label: I18n.tr("Focused") },
            { value: "region", label: I18n.tr("Region") },
        ]
        onChosen: value => Recorder.set({ target: value })
    }

    Choices {
        title: I18n.tr("Quality")
        current: Recorder.settings.quality
        options: [
            { value: "medium", label: I18n.tr("Medium") },
            { value: "high", label: I18n.tr("High") },
            { value: "very_high", label: I18n.tr("Very high") },
            { value: "ultra", label: I18n.tr("Ultra") },
        ]
        onChosen: value => Recorder.set({ quality: value })
    }

    Choices {
        title: I18n.tr("Codec")
        current: Recorder.settings.codec
        options: [
            { value: "auto", label: I18n.tr("Auto") },
            { value: "h264", label: "H.264" },
            { value: "hevc", label: "HEVC" },
            { value: "av1", label: "AV1" },
        ]
        onChosen: value => Recorder.set({ codec: value })
    }

    Choices {
        title: I18n.tr("Frame rate")
        current: Recorder.settings.fps
        options: [
            { value: 30, label: "30" },
            { value: 60, label: "60" },
            { value: 120, label: "120" },
        ]
        onChosen: value => Recorder.set({ fps: value })
    }

    Choices {
        title: I18n.tr("Audio")
        current: Recorder.settings.audio
        options: [
            { value: "", label: I18n.tr("Silent") },
            { value: "default_output", label: I18n.tr("Output") },
            { value: "default_input", label: I18n.tr("Microphone") },
            { value: "default_output|default_input", label: I18n.tr("Both") },
        ]
        onChosen: value => Recorder.set({ audio: value })
    }

    Txt {
        visible: Recorder.recording
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        text: I18n.tr("Changes apply to the next recording")
        dim: true
    }
}
