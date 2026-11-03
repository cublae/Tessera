import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// A quick-settings tile, Android's pill: the body toggles, and a tile with a
// page behind it carries a round button inside it that opens the page.
//
// Width is fixed by the grid, never by the text: a long network name would
// otherwise push its column wider than the other.
Item {
    id: root

    property string icon: ""
    property string label: ""
    property string subtitle: ""
    property bool active: false
    property bool expandable: false

    signal toggled
    signal expand

    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.preferredHeight: 68

    readonly property color tint: active ? Theme.accentBg : Theme.fieldBg
    readonly property color ink: active ? Theme.accentFg : Theme.fg
    // State layers are a wash of the ink, so they read on either fill.
    readonly property color hoverTint: Theme.mix(tint, ink, 0.08)
    readonly property color pressTint: Theme.mix(tint, ink, 0.12)

    Button {
        anchors.fill: parent
        color: pressed ? root.pressTint : hovered ? root.hoverTint : root.tint
        fill: true
        padding: 18
        onClicked: root.toggled()

        RowLayout {
            Layout.fillWidth: true
            Layout.rightMargin: root.expandable ? 28 : 0
            spacing: 12

            Icon {
                name: root.icon
                size: 22
                color: root.ink
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Txt {
                    Layout.fillWidth: true
                    text: root.label
                    color: root.ink
                    font.weight: Font.Medium
                }

                Txt {
                    Layout.fillWidth: true
                    text: root.subtitle
                    color: root.ink
                    em: 0.85
                    opacity: 0.8
                }
            }
        }
    }

    Button {
        visible: root.expandable
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 32
        height: 32
        padding: 0
        minHeight: 0
        color: pressed ? Theme.alpha(root.ink, 0.2) : hovered ? Theme.alpha(root.ink, 0.12) : "transparent"
        tooltip: I18n.tr("Show all")
        onClicked: root.expand()

        Icon {
            name: "go-next-symbolic"
            size: 16
            color: root.ink
        }
    }
}
