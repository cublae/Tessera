import QtQuick
import qs.services
import qs.components

// The launcher opens on a search field, so it is a magnifier rather than an
// app grid.
IconButton {
    property var bar

    readonly property bool shown: Config.c.modules.launcher

    icon: Icons.first(["system-search-symbolic", "edit-find-symbolic"])
    padding: Theme.spacing
    minHeight: 24
    tooltip: I18n.tr("Search applications")
    onClicked: bar.toggle("launcher")
}
