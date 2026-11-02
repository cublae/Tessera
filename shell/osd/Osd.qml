import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components

// The overlay for volume, microphone, brightness and keyboard layout.
//
// It reacts to the values themselves rather than to keys, so a change from
// anywhere -- a media key, a mixer, a script -- shows the same way. Other parts
// of the shell post to it through `Shell.osd`, the colour picker among them.
PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property string position: Config.c.osd.position

    property string icon: ""
    property real level: -1
    property string text: ""
    property string swatch: ""
    property bool showing: false

    screen: modelData
    visible: showing || fade.running
    color: "transparent"
    implicitWidth: panel.width + 40
    implicitHeight: panel.height + 40
    mask: Region {}

    WlrLayershell.namespace: "tessera-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Normal

    anchors {
        top: position === "top"
        bottom: position === "bottom"
    }
    margins.bottom: 24
    margins.top: 24

    function show(message: var): void {
        icon = message.icon ?? ""
        swatch = message.swatch ?? ""
        if (message.level !== undefined) {
            level = Math.min(1, Math.max(0, message.level))
            text = `${Math.round(level * 100)}`
        } else {
            level = -1
            text = message.text ?? ""
        }
        showing = true
        hide.restart()
    }

    Timer {
        id: hide

        interval: Math.max(200, Config.c.osd.timeout)
        onTriggered: root.showing = false
    }

    Connections {
        target: Shell
        function onOsd(message) {
            root.show(message)
        }
    }

    // Values that change at startup, before anyone touched anything, must not
    // flash the overlay; `primed` holds it back until the first settled value.
    property bool primed: false
    Timer {
        running: true
        interval: 1500
        onTriggered: root.primed = true
    }

    readonly property var speakerAudio: Audio.speaker?.audio ?? null
    readonly property var micAudio: Audio.microphone?.audio ?? null

    Connections {
        target: root.speakerAudio
        function onVolumeChanged() { root.speakerChanged() }
        function onMutedChanged() { root.speakerChanged() }
    }

    Connections {
        target: root.micAudio
        function onVolumeChanged() { root.micChanged() }
        function onMutedChanged() { root.micChanged() }
    }

    Connections {
        target: Brightness
        function onRawChanged() {
            if (root.primed) root.show({ icon: "display-brightness-symbolic", level: Brightness.brightness })
        }
    }

    Connections {
        target: Niri
        function onKeyboardLayoutsChanged() {
            if (root.primed && Niri.keyboardLayouts.names.length > 1)
                root.show({ icon: "input-keyboard-symbolic", text: Niri.keyboardLayout })
        }
    }

    function speakerChanged(): void {
        const audio = speakerAudio
        if (!primed || !audio) return
        show({ icon: Audio.volumeIcon(audio.volume, audio.muted), level: audio.muted ? 0 : audio.volume })
    }

    function micChanged(): void {
        const audio = micAudio
        if (!primed || !audio) return
        show({ icon: Audio.micIcon(audio.volume, audio.muted), level: audio.muted ? 0 : audio.volume })
    }

    Rectangle {
        id: panel

        anchors.centerIn: parent
        width: row.implicitWidth + 32
        height: row.implicitHeight + 24
        radius: Theme.radiusLg
        color: Theme.panelBg
        border.color: Theme.borders
        border.width: 1
        opacity: root.showing ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                id: fade

                duration: Theme.duration
            }
        }

        RowLayout {
            id: row

            anchors.centerIn: parent
            spacing: 12

            Icon {
                visible: root.swatch === ""
                name: root.icon
                size: 24
            }

            Rectangle {
                visible: root.swatch !== ""
                width: 24
                height: 24
                radius: Theme.radiusSm
                color: root.swatch || "transparent"
                border.color: Theme.borders
                border.width: 1
            }

            // The level bar follows the shell's radius unless `osd.barRadius`
            // says otherwise; a square bar inside rounded panels looks like
            // something the theme forgot.
            Rectangle {
                id: track

                visible: root.level >= 0
                Layout.preferredWidth: 180
                Layout.preferredHeight: 6
                readonly property real r: Math.min(height / 2, Config.c.osd.barRadius ?? Theme.radius)
                radius: r
                color: Theme.alpha(Theme.fg, 0.15)

                Rectangle {
                    width: parent.width * Math.max(0, root.level)
                    height: parent.height
                    radius: track.r
                    color: Theme.accentBg

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.fast
                        }
                    }
                }
            }

            Txt {
                text: root.text
                Layout.preferredWidth: root.level >= 0 ? 32 : implicitWidth
                horizontalAlignment: Text.AlignRight
                font.features: { "tnum": 1 }
            }
        }
    }
}
