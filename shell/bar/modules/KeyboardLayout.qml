import QtQuick
import qs.services
import qs.components

// The active keyboard layout as a two-letter code; click to switch.
//
// Compositors name layouts the way xkb describes them -- "English (US)" -- which is
// too long for a bar. The first letters of the language are what every other
// desktop shows, so that is what this shows.
Button {
    id: root

    property var bar

    readonly property bool shown: Compositor.keyboardLayouts.names.length > 1

    tooltip: Compositor.keyboardLayout
    onClicked: Compositor.switchLayout()

    Txt {
        text: (Compositor.keyboardLayout.split(" ")[0] ?? "").slice(0, 2).toUpperCase()
        em: 0.85
        font.weight: Font.DemiBold
        font.letterSpacing: 0.5
    }
}
