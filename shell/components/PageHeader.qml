import QtQuick
import QtQuick.Layouts
import qs.services

// The header of a control-center page: back, a title, and whatever controls
// the page puts after it.
RowLayout {
    id: root

    property string title: ""
    default property alias trailing: extra.data

    signal back

    spacing: 6
    Layout.fillWidth: true

    IconButton {
        icon: "go-previous-symbolic"
        tooltip: I18n.tr("Back")
        onClicked: root.back()
    }

    Txt {
        Layout.fillWidth: true
        text: root.title
        font.weight: Font.Medium
        em: 1.2
    }

    RowLayout {
        id: extra

        spacing: 6
    }
}
