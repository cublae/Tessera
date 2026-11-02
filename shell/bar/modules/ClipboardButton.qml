import QtQuick
import qs.services
import qs.components

IconButton {
    property var bar

    readonly property bool shown: Clipboard.available && Config.c.modules.clipboard

    icon: "edit-paste-symbolic"
    padding: Theme.spacing
    minHeight: 24
    tooltip: I18n.tr("Clipboard history")
    onClicked: bar.toggle("clipboard")
}
