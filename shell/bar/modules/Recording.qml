import QtQuick
import qs.services
import qs.components

// Visible only while recording: a timer, and a click stops it.
Button {
    property var bar

    readonly property bool shown: Recorder.recording

    tooltip: I18n.tr("Stop recording")
    onClicked: Recorder.stop()

    Rectangle {
        width: 8
        height: 8
        radius: 4
        color: Theme.destructive
    }

    Txt {
        text: Recorder.clock(Recorder.elapsed)
        font.features: { "tnum": 1 }
    }
}
