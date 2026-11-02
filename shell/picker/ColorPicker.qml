import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components

// The colour picker's overlay on one output: the frozen screen, a crosshair,
// and a lens of magnified pixels following the cursor.
PanelWindow {
    id: root

    required property ShellScreen modelData

    // Pixels across the lens, and how large each is drawn.
    readonly property int sample: 17
    readonly property int cell: 10
    readonly property int glass: sample * cell
    readonly property int offset: 24

    readonly property string capture: Picker.captures[modelData.name] ?? ""

    property int px: 0
    property int py: 0
    property string hex: ""
    property real mouseX: -1000
    property real mouseY: -1000

    screen: modelData
    visible: Picker.active && capture !== ""
    color: "black"

    WlrLayershell.namespace: "tessera-picker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    onVisibleChanged: if (visible) keys.forceActiveFocus()

    function pixel(x: int, y: int): var {
        const data = reader.getContext("2d").getImageData(x, y, 1, 1).data
        return [data[0], data[1], data[2]]
    }

    function follow(x: real, y: real): void {
        if (shot.status !== Image.Ready || width <= 0) return
        mouseX = x
        mouseY = y
        px = Math.max(0, Math.min(shot.sourceSize.width - 1, Math.floor(x / width * shot.sourceSize.width)))
        py = Math.max(0, Math.min(shot.sourceSize.height - 1, Math.floor(y / height * shot.sourceSize.height)))
        if (reader.ready) hex = "#" + pixel(px, py).map(c => c.toString(16).padStart(2, "0")).join("")
    }

    Image {
        id: shot

        anchors.fill: parent
        source: root.capture ? "file://" + root.capture : ""
        cache: false
        fillMode: Image.Stretch
        onStatusChanged: if (status === Image.Ready) reader.loadImage(source)
    }

    // The capture at its own resolution, kept only to read pixels out of. It
    // has to be painted to be readable, so it sits behind the picture rather
    // than being hidden.
    Canvas {
        id: reader

        property bool ready: false

        z: -1
        width: shot.sourceSize.width
        height: shot.sourceSize.height
        renderStrategy: Canvas.Immediate
        onImageLoaded: requestPaint()
        onPaint: {
            if (!isImageLoaded(shot.source)) return
            const context = getContext("2d")
            context.drawImage(shot.source, 0, 0, width, height)
            ready = true
            // Read the pixel under the pointer now that there is something to
            // read; until the pointer moves, the lens shows the middle.
            if (root.mouseX < 0) root.follow(root.width / 2, root.height / 2)
            else root.follow(root.mouseX, root.mouseY)
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.CrossCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPositionChanged: mouse => root.follow(mouse.x, mouse.y)
        onEntered: root.follow(mouseX, mouseY)
        onClicked: mouse => {
            if (mouse.button !== Qt.LeftButton || !reader.ready) Picker.finish(null)
            else Picker.finish(root.pixel(root.px, root.py))
        }
    }

    Item {
        id: keys

        focus: true
        Keys.onEscapePressed: Picker.finish(null)
    }

    // The lens: the capture drawn large and shifted so the sampled pixel sits
    // in the middle, unsmoothed so every pixel stays a square.
    Rectangle {
        id: card

        width: root.glass
        height: root.glass + 28
        radius: Theme.radiusMd
        color: Theme.panelBg
        border.color: Theme.borders
        border.width: 1
        clip: true

        x: {
            const left = root.mouseX + root.offset
            return left + width > root.width ? root.mouseX - root.offset - width : left
        }
        y: {
            const top = root.mouseY + root.offset
            return top + height > root.height ? root.mouseY - root.offset - height : top
        }

        Item {
            id: lens

            width: root.glass
            height: root.glass
            clip: true

            Image {
                source: shot.source
                cache: false
                smooth: false
                width: shot.sourceSize.width * root.cell
                height: shot.sourceSize.height * root.cell
                x: -(root.px - Math.floor(root.sample / 2)) * root.cell
                y: -(root.py - Math.floor(root.sample / 2)) * root.cell
            }

            Rectangle {
                x: Math.floor(root.sample / 2) * root.cell
                y: Math.floor(root.sample / 2) * root.cell
                width: root.cell
                height: root.cell
                color: "transparent"
                border.color: "white"
                border.width: 1

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -1
                    color: "transparent"
                    border.color: "black"
                    border.width: 1
                }
            }
        }

        Txt {
            anchors.top: lens.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 28
            horizontalAlignment: Text.AlignHCenter
            text: root.hex.toUpperCase()
            font.family: "monospace"
        }
    }
}
