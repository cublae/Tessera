import QtQuick
import qs.services

// A vertically scrolling area with a thin indicator.
Flickable {
    id: root

    default property alias content: column.data
    property alias spacing: column.spacing

    contentHeight: column.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height

    // Keep a row in view, for keyboard navigation through a list.
    function reveal(item: Item): void {
        const top = item.mapToItem(column, 0, 0).y
        const bottom = top + item.height
        if (top < contentY) contentY = top
        else if (bottom > contentY + height) contentY = bottom - height
    }

    Column {
        id: column

        width: root.width
    }

    Rectangle {
        visible: root.interactive
        parent: root
        anchors.right: parent.right
        width: 3
        radius: 1.5
        color: Theme.alpha(Theme.fg, 0.3)
        y: root.visibleArea.yPosition * root.height
        height: root.visibleArea.heightRatio * root.height
    }
}
