import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.services

// A themed icon, a file, or a tray item's image.
//
// Symbolic icons are drawn in one grey and recoloured by whoever displays them;
// GTK does that with the text colour, so this does too. Anything else keeps its
// own colours.
Item {
    id: root

    property string name: ""
    property string fallback: ""
    // A ready-made image source -- a tray item's `icon`, say -- instead of a name.
    property string source: ""
    property int size: 16
    property color color: Theme.fg
    readonly property string resolved: source || (name || fallback ? Icons.source(name, fallback) : "")
    property bool recolor: source === "" && resolved.indexOf("-symbolic") !== -1
    property bool dim: false

    implicitWidth: size
    implicitHeight: size
    opacity: dim ? Theme.dimOpacity : 1

    IconImage {
        anchors.fill: parent
        implicitSize: root.size
        asynchronous: true
        source: root.resolved

        layer.enabled: root.recolor
        layer.effect: MultiEffect {
            brightness: 1
            colorization: 1
            colorizationColor: root.color
        }
    }
}
