import QtQuick
import qs.services
import qs.components

IconButton {
    property var bar

    readonly property bool shown: Config.c.modules.controlCenter

    icon: "open-menu-symbolic"
    padding: Theme.spacing
    minHeight: 24
    tooltip: I18n.tr("Control center")
    onClicked: bar.toggle("control-center")
}
