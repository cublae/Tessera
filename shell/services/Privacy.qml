pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Who is listening and who is watching.
//
// Two very different questions with two very different answers. The
// microphone is PipeWire's to answer: an application recording audio holds a
// capture stream, and the stream names its owner.
//
// The camera has no such registry. An application opens `/dev/videoN` directly
// and nothing announces it, so the only honest way to tell is to look for a
// process holding one of those nodes open -- by walking `/proc`, which only sees
// the user's own processes, and in practice that is every application that
// would use a webcam. Opening a device file emits nothing anyone can subscribe
// to, so it is a poll, and it is skipped outright on a machine with no camera.
Singleton {
    id: root

    // A muted stream is still an open microphone, and saying otherwise would be
    // the one lie this indicator must not tell: an application that mutes
    // itself can unmute itself.
    readonly property var microphone: unique(Audio.recorders.map(node => Audio.streamName(node)))
    property var camera: []

    readonly property bool microphoneInUse: microphone.length > 0
    readonly property bool cameraInUse: camera.length > 0

    property bool hasCamera: false

    function unique(names: var): var {
        return names.filter((name, at) => names.indexOf(name) === at)
    }

    Process {
        running: true
        command: ["sh", "-c", "ls /dev/video[0-9]* >/dev/null 2>&1"]
        onExited: code => root.hasCamera = code === 0
    }

    Timer {
        running: root.hasCamera
        repeat: true
        triggeredOnStart: true
        interval: 3000
        onTriggered: scan.running = true
    }

    // One `find` over every fd of every process, then the owners' names from
    // `comm` -- the process's own name, as a task list shows it, rather than a
    // command line that is a path and a screenful of flags.
    Process {
        id: scan

        command: ["sh", "-c", "find /proc/[0-9]*/fd -maxdepth 1 -lname '/dev/video*' 2>/dev/null | cut -d/ -f3 | sort -u | while read -r pid; do cat /proc/$pid/comm 2>/dev/null; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const next = root.unique(text.split("\n").map(l => l.trim()).filter(Boolean))
                if (next.join("\n") !== root.camera.join("\n")) root.camera = next
            }
        }
    }
}
