pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Pick a colour off the screen and put it on the clipboard.
//
// The screen is frozen first -- one grim capture per output -- and the overlay
// shows that capture with a magnifier over it. Reading the pixel from the
// capture rather than the live screen is what makes the colour the one under
// the cursor at the moment of the click, and the only way to show the pixels
// around it large enough to aim at.
//
// The user gets the hex on the clipboard, because that is the only reason
// anyone picks a colour, and the overlay showing the colour itself, because a
// clipboard write with no feedback looks exactly like nothing happening.
// Cancelling is a normal outcome and passes silently.
Singleton {
    id: root

    property bool active: false
    // Capture path per output name, once grim has written them.
    property var captures: ({})

    function file(output: string): string {
        return `${Paths.runtime}/pick-${output}.png`
    }

    function pick(): void {
        if (active || grab.running) return
        const outputs = Quickshell.screens.map(s => s.name)
        grab.command = ["sh", "-c", "for o in \"$@\"; do grim -o \"$o\" \"" + Paths.runtime + "/pick-$o.png\" || exit 1; done", "sh"].concat(outputs)
        grab.outputs = outputs
        grab.running = true
    }

    function finish(rgb: var): void {
        if (!active) return
        active = false
        captures = {}
        if (!rgb) return

        const hex = "#" + rgb.map(c => Math.round(c).toString(16).padStart(2, "0")).join("")
        Clipboard.copyText(hex)
        Shell.osd({ icon: "color-select-symbolic", text: hex, swatch: hex })
    }

    Process {
        id: grab

        property var outputs: []

        onExited: code => {
            if (code !== 0) {
                console.error("tessera: could not capture the screen for the colour picker")
                return
            }
            const captures = {}
            for (const output of outputs) captures[output] = root.file(output)
            root.captures = captures
            root.active = true
        }
    }
}
