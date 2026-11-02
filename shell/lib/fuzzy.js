.pragma library

// Fuzzy matching for the launcher.
//
// A query matches a name when its characters appear in it in order, the way
// "ffx" finds Firefox. How well it matches is worth more than whether: a run of
// consecutive characters beats scattered ones, a hit at the start of a word
// beats one in the middle, and a hit at the very start beats both. The score is
// normalised to 0..1 so `launcher.minScore` reads the same whatever the length
// of the query.

function subsequence(query, text) {
    if (!query) return 0
    if (!text) return -1

    const haystack = text.toLowerCase()
    const needle = query.toLowerCase()

    // A literal substring is the best kind of match and short-circuits the
    // character walk.
    const literal = haystack.indexOf(needle)
    if (literal === 0) return 1
    if (literal > 0) {
        const boundary = /[\s\-_.]/.test(haystack[literal - 1])
        return boundary ? 0.9 : 0.75
    }

    let score = 0
    let at = 0
    let run = 0
    for (let i = 0; i < needle.length; i++) {
        const found = haystack.indexOf(needle[i], at)
        if (found === -1) return -1

        const boundary = found === 0 || /[\s\-_.]/.test(haystack[found - 1])
        run = found === at && i > 0 ? run + 1 : 0
        score += 1 + run + (boundary ? 1.5 : 0)
        at = found + 1
    }

    // Best possible: every character a boundary hit in one unbroken run.
    const best = needle.length * 2.5 + (needle.length * (needle.length - 1)) / 2
    return Math.min(0.7, (score / best) * 0.7)
}

// Score an application: its name counts fully, the rest progressively less.
function scoreEntry(query, entry) {
    const fields = [
        [entry.name, 1],
        [entry.genericName, 0.8],
        [entry.keywords, 0.75],
        [entry.id, 0.7],
        [entry.comment, 0.5],
    ]

    let best = -1
    for (const [text, weight] of fields) {
        const value = subsequence(query, text ? String(text) : "")
        if (value >= 0) best = Math.max(best, value * weight)
    }
    return best
}
