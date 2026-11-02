import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// Visible only while the microphone or the camera is in use; the tooltip says
// who. Clicking the microphone mutes it -- the application keeps its stream,
// it just hears nothing.
RowLayout {
    id: root

    property var bar

    readonly property bool shown: Privacy.microphoneInUse || Privacy.cameraInUse
    readonly property bool muted: Audio.microphone?.audio?.muted ?? false

    spacing: 2

    Button {
        visible: Privacy.microphoneInUse
        active: true
        activeColor: Theme.alpha(root.muted ? Theme.fg : Theme.warning, 0.2)
        tooltip: `${root.muted ? I18n.tr("Microphone muted") : I18n.tr("Microphone in use")}: ${Privacy.microphone.join(", ")}`
        onClicked: {
            const audio = Audio.microphone?.audio
            if (audio) audio.muted = !audio.muted
        }

        Icon {
            name: root.muted ? "microphone-disabled-symbolic" : "audio-input-microphone-symbolic"
            color: root.muted ? Theme.fg : Theme.warning
        }
    }

    Button {
        visible: Privacy.cameraInUse
        active: true
        activeColor: Theme.alpha(Theme.warning, 0.2)
        tooltip: `${I18n.tr("Camera in use")}: ${Privacy.camera.join(", ")}`

        Icon {
            name: "camera-web-symbolic"
            color: Theme.warning
        }
    }
}
