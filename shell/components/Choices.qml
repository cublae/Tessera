import QtQuick
import QtQuick.Layouts
import qs.services

// A labelled row of mutually exclusive options.
ColumnLayout {
    id: root

    property string title: ""
    // `[{ value, label }]`.
    property var options: []
    property var current

    signal chosen(var value)

    spacing: 4
    Layout.fillWidth: true

    Txt {
        text: root.title
        dim: true
        em: 0.9
    }

    RowLayout {
        spacing: 4
        Layout.fillWidth: true

        Repeater {
            model: root.options

            Button {
                required property var modelData

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                minHeight: 30
                active: root.current === modelData.value
                activeColor: Theme.secondaryContainer
                onClicked: root.chosen(modelData.value)

                Txt {
                    text: modelData.label
                    color: root.current === modelData.value ? Theme.secondaryContainerFg : Theme.fg
                }
            }
        }
    }
}
