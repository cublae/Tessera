pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../lib/defaults.js" as Defaults

// The live configuration.
//
// One JSON file, deep-merged over the defaults, so a user -- or the Home
// Manager module -- only ever states what differs. The file is watched and
// edits apply in place: everything that reads `Config.c` is a binding, so a
// changed module list or bar position re-lays itself out without a restart.
//
// A broken file never takes the shell down. It is logged and the defaults
// stand until it parses again.
Singleton {
    id: root

    readonly property string path: {
        const override = Quickshell.env("TESSERA_CONFIG")
        if (override) return override
        const base = Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"
        return base + "/tessera/config.json"
    }

    // The merged config. Bind to narrow paths -- `Config.c.clock.format` -- the
    // way any QML property is read.
    property var c: Defaults.config

    signal reloaded

    function reload(): void {
        file.reload()
    }

    function apply(text: string): void {
        try {
            c = Defaults.parse(text)
        } catch (error) {
            console.error(`tessera: could not read ${path}, using defaults: ${error}`)
            c = Defaults.config
        }
        reloaded()
    }

    FileView {
        id: file

        path: root.path
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: root.apply(text())
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound)
                console.error(`tessera: could not open ${root.path}: ${FileViewError.toString(error)}`)
            else
                console.log(`tessera: no config at ${root.path}, using defaults`)
            // A fresh object, not the defaults themselves: anything that read
            // `c` before the file answered re-reads it on the assignment.
            root.c = Defaults.parse("{}")
        }
    }
}
