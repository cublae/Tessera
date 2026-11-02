pragma Singleton

import QtQuick
import Quickshell
import qs.components

import "../lib/fuzzy.js" as Fuzzy

// Installed applications, for the launcher.
//
// Quickshell indexes the desktop entries and follows the application
// directories, so a newly installed program shows up without a restart. On
// top of that the shell keeps two small files: which entries are pinned to the
// top, and how often each was launched, which orders the list when nothing is
// typed.
Singleton {
    id: root

    readonly property var all: DesktopEntries.applications.values
        .filter(app => Config.c.launcher.showHidden || !app.noDisplay)
        .slice()
        .sort((a, b) => frequency(b) - frequency(a) || a.name.localeCompare(b.name))

    readonly property var pinned: pinnedFile.value

    function frequency(app: var): int {
        return launchesFile.value[app.id] ?? 0
    }

    function isPinned(app: var): bool {
        return pinned.indexOf(app.id) !== -1
    }

    function togglePin(app: var): void {
        const list = pinned.slice()
        const at = list.indexOf(app.id)
        if (at === -1) list.push(app.id)
        else list.splice(at, 1)
        pinnedFile.save(list)
    }

    function launch(app: var): void {
        const counts = Object.assign({}, launchesFile.value)
        counts[app.id] = (counts[app.id] ?? 0) + 1
        launchesFile.save(counts)
        app.execute()
    }

    // Matches for `query`, best first, or the full list with pins on top.
    function search(query: string): var {
        const term = query.trim()
        if (!term) {
            const byId = new Map(all.map(app => [app.id, app]))
            const top = pinned.map(id => byId.get(id)).filter(app => app)
            return top.concat(all.filter(app => !isPinned(app)))
        }

        const minScore = Config.c.launcher.minScore
        const scored = []
        for (const app of all) {
            const score = Fuzzy.scoreEntry(term, app)
            if (score >= minScore) scored.push([app, score])
        }
        scored.sort((a, b) => b[1] - a[1] || frequency(b[0]) - frequency(a[0]))
        return scored.map(pair => pair[0])
    }

    JsonFile {
        id: pinnedFile

        path: Paths.state + "/pinned.json"
        fallback: []
    }

    JsonFile {
        id: launchesFile

        path: Paths.state + "/launches.json"
        fallback: ({})
    }
}
