pragma Singleton

import QtQuick
import Quickshell

// Where the shell keeps what it writes.
//
// Not Quickshell's own per-shell directories: those are keyed by a hash of the
// config path, which moves with every store path, and a layout arranged by hand
// should survive an upgrade.
Singleton {
    readonly property string home: Quickshell.env("HOME")
    readonly property string state: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/tessera"
    readonly property string cache: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/tessera"
    readonly property string config: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/tessera"
    readonly property string runtime: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/tessera"

    // Owner-only: the clipboard history is plain text, and the rest is nobody
    // else's business either.
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", "-m", "700", state, cache, config, runtime])
}
