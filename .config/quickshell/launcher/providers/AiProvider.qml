import QtQuick
import Quickshell
import Quickshell.Io

// AI provider — Gemini streamGenerateContent (SSE).
// Multi-turn conversation; history persists across launcher reopens.
// Triggered only via "ai " prefix — Enter submits, response streams inline.
Item {
    id: root
    visible: false

    readonly property string providerId: "ai"
    readonly property string badge: "AI"

    // Stable model. ~/.askai-env override (GEMINI_MODEL=...).
    property string model: "gemini-2.0-flash"

    property string apiKey: ""
    property bool   apiKeyReady: false
    property bool   keyMissing: false
    property string keyError: ""

    property string response: ""
    property string error: ""
    property bool   streaming: false
    property var    history: []   // [{role: "user"|"model", text: ...}]
    readonly property string requestHelper: (Quickshell.env("HOME") || "")
        + "/.config/quickshell/launcher/providers/gemini-request.py"

    signal responseUpdated()
    signal responseDone()
    signal responseError(string msg)

    Process {
        id: envLoader
        command: ["sh", "-c", "test -r \"$1\" && cat \"$1\"", "_",
            (Quickshell.env("HOME") || "") + "/.askai-env"]
        stdout: StdioCollector { id: envOut }
        onExited: code => {
            if (code !== 0) {
                root.apiKey = ""
                root.apiKeyReady = true
                root.keyMissing = true
                root.keyError = "Cannot read ~/.askai-env"
                return
            }
            const txt = envOut.text || ""
            const k = txt.match(/^\s*(?:export\s+)?GEMINI_API_KEY\s*=\s*['"]?([^'"\r\n]+)['"]?\s*$/m)
            const m = txt.match(/^\s*(?:export\s+)?GEMINI_MODEL\s*=\s*['"]?([^'"\r\n]+)['"]?\s*$/m)
            root.apiKey = k ? k[1] : ""
            if (m) root.model = m[1]
            root.apiKeyReady = true
            root.keyMissing = !root.apiKey
            root.keyError = root.apiKey ? "" : "GEMINI_API_KEY missing in ~/.askai-env"
        }
    }

    Component.onCompleted: envLoader.running = true

    Process {
        id: askProc
        property string pendingInput: ""
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => root._handleSseLine(line)
        }
        stderr: StdioCollector { id: errBuf }
        onStarted: {
            if (pendingInput.length > 0) {
                write(pendingInput)
                pendingInput = ""
            }
        }
        onExited: (code, status) => {
            root.streaming = false
            if (code !== 0 && !root.response && !root.error) {
                const tail = (errBuf.text || "").split("\n").slice(-3).join(" ").trim()
                root.error = "Request failed (exit " + code + ")"
                    + (tail ? " — " + tail : "")
                root.responseError(root.error)
                return
            }
            if (root.response && !root.error) {
                // Snapshot streaming buffer into history (Repeater needs new array ref).
                root.history = root.history.concat([{ role: "model", text: root.response }])
                root.response = ""
                root.responseDone()
            }
        }
    }

    function _handleSseLine(line) {
        if (!line.startsWith("data: ")) return
        const payload = line.slice(6).trim()
        if (!payload || payload === "[DONE]") return
        let obj
        try { obj = JSON.parse(payload) } catch (e) { return }

        if (obj.error) {
            root.error = obj.error.message || "API error"
            root.responseError(root.error)
            return
        }
        const cands = obj.candidates || []
        for (let i = 0; i < cands.length; i++) {
            const parts = (cands[i].content && cands[i].content.parts) || []
            for (let j = 0; j < parts.length; j++) {
                if (parts[j].text) {
                    root.response += parts[j].text
                    root.responseUpdated()
                }
            }
        }
    }

    function ask(prompt) {
        const p = (prompt || "").trim()
        if (!p) return
        if (root.streaming) return
        if (!root.apiKeyReady) {
            root.error = "API key not loaded yet"
            root.responseError(root.error)
            return
        }
        if (!root.apiKey) {
            root.error = root.keyError || "GEMINI_API_KEY missing"
            root.responseError(root.error)
            return
        }

        // Append user turn first so it shows in convo immediately.
        root.history = root.history.concat([{ role: "user", text: p }])
        root.response = ""
        root.error = ""
        root.streaming = true

        const contents = root.history.map(t => ({
            role: t.role,
            parts: [{ text: t.text }]
        }))
        const body = JSON.stringify({ contents: contents })

        const url = "https://generativelanguage.googleapis.com/v1beta/models/"
            + root.model + ":streamGenerateContent?alt=sse"

        // Keep the API key and conversation out of argv/process listings.
        // The helper receives both over stdin and streams curl's SSE output.
        askProc.pendingInput = JSON.stringify({
            apiKey: root.apiKey,
            body: body,
            url: url
        })
        askProc.command = ["python3", requestHelper]
        askProc.running = true
    }

    function cancel() {
        if (askProc.running) askProc.running = false
        root.streaming = false
    }

    function reset() {
        cancel()
        root.history = []
        root.response = ""
        root.error = ""
    }
}
