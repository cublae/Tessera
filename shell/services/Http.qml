pragma Singleton

import QtQuick
import Quickshell

// The HTTP the shell does: weather, and the proxy core's controller.
Singleton {
    // Perform a request; `callback(error, body)` gets the text of a 2xx answer,
    // or an error string. A 2xx with no body is a perfectly good answer to a
    // PUT or a PATCH, so it resolves to the empty string.
    function request(url: string, options: var, callback: var): void {
        const xhr = new XMLHttpRequest()
        const opts = options ?? {}
        xhr.open(opts.method ?? "GET", url)
        for (const name of Object.keys(opts.headers ?? {})) xhr.setRequestHeader(name, opts.headers[name])
        xhr.timeout = opts.timeout ?? 15000

        let done = false
        const finish = (error, body) => {
            if (done) return
            done = true
            if (callback) callback(error, body)
        }

        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status >= 200 && xhr.status < 300) finish(null, xhr.responseText ?? "")
            else finish(xhr.status ? `${url} answered ${xhr.status}` : `${url}: no answer`, null)
        }
        xhr.ontimeout = () => finish(`${url}: timed out`, null)

        if (opts.json !== undefined) {
            xhr.setRequestHeader("Content-Type", "application/json")
            xhr.send(JSON.stringify(opts.json))
        } else {
            xhr.send()
        }
    }

    function getJson(url: string, callback: var): void {
        request(url, {}, (error, body) => {
            if (error) return callback(error, null)
            try {
                callback(null, JSON.parse(body))
            } catch (parseError) {
                callback(`${url}: ${parseError}`, null)
            }
        })
    }

    // A query string, encoded by hand.
    function query(params: var): string {
        return Object.keys(params).map(key => `${encodeURIComponent(key)}=${encodeURIComponent(params[key])}`).join("&")
    }
}
