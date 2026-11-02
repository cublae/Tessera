import QtQuick
import Quickshell
import Quickshell.Io

// A small JSON document on disk: read once, written whole on every change.
//
// The file belongs to the shell, but it is a file, and a hand-edited one should
// not crash anything -- an unreadable document reads as `fallback`.
FileView {
    id: root

    property var fallback: ({})
    property var value: fallback

    signal ready

    function save(next: var): void {
        value = next
        setText(JSON.stringify(next, null, 2))
    }

    printErrors: false
    atomicWrites: true

    onLoaded: {
        try {
            const parsed = JSON.parse(text())
            value = parsed ?? fallback
        } catch (error) {
            console.error(`tessera: could not read ${path}: ${error}`)
            value = fallback
        }
        ready()
    }
    onLoadFailed: {
        value = fallback
        ready()
    }
    onSaveFailed: error => console.error(`tessera: could not save ${path}: ${FileViewError.toString(error)}`)
}
