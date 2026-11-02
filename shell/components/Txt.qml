import QtQuick
import qs.services

// Text in the shell's face and colour.
Text {
    // Size relative to the base font.
    property real em: 1
    property bool dim: false

    color: Theme.fg
    opacity: dim ? Theme.dimOpacity : 1
    font.family: Theme.fontFamily
    font.pointSize: Theme.fontSize * em
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
}
