import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// A quick-settings tile: the body toggles, the chevron opens the page behind it.
//
// Tiles without a page are one piece. Width is fixed by the grid, never by the
// text: a long network name would otherwise push its column wider than the
// other.
RowLayout {
    id: root

    property string icon: ""
    property string label: ""
    property string subtitle: ""
    property bool active: false
    property bool expandable: false

    signal toggled
    signal expand

    spacing: 1
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.preferredHeight: 52

    readonly property color tint: active ? Theme.accentBg : Theme.alpha(Theme.fg, 0.1)
    readonly property color ink: active ? Theme.accentFg : Theme.fg

    Button {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: hovered ? Qt.lighter(root.tint, root.active ? 1.08 : 1.4) : root.tint
        activeColor: root.tint
        radius: Theme.radiusLg
        topRightRadius: root.expandable ? 0 : radius
        bottomRightRadius: root.expandable ? 0 : radius
        fill: true
        padding: 10
        onClicked: root.toggled()

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Icon {
                name: root.icon
                size: 18
                color: root.ink
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Txt {
                    Layout.fillWidth: true
                    text: root.label
                    color: root.ink
                    font.weight: Font.Bold
                }

                Txt {
                    Layout.fillWidth: true
                    text: root.subtitle
                    color: root.ink
                    em: 0.85
                    opacity: 0.85
                }
            }
        }
    }

    Button {
        visible: root.expandable
        Layout.preferredWidth: 24
        Layout.fillHeight: true
        color: hovered ? Qt.lighter(root.tint, root.active ? 1.08 : 1.4) : root.tint
        radius: Theme.radiusLg
        topLeftRadius: 0
        bottomLeftRadius: 0
        padding: 0
        minHeight: 0
        tooltip: I18n.tr("Show all")
        onClicked: root.expand()

        Icon {
            name: "go-next-symbolic"
            size: 14
            color: root.ink
        }
    }
}
