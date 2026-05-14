pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Single source of truth for the MCP Manager.
// Wraps `mcp-helpers.py` (which itself wraps `docker mcp`).
// All reads are async Process calls; results are normalised JSON.
Singleton {
    id: root

    // ── helper script path ───────────────────────────────────────
    readonly property string helper:
        (Quickshell.env("HOME") || "") + "/.config/quickshell/services/mcp/mcp-helpers.py"
    readonly property string secretsPath:
        (Quickshell.env("HOME") || "") + "/.docker/mcp/secrets.env"

    // ── reactive store ───────────────────────────────────────────
    property var catalog: []                  // [{name, description}]
    property var servers: []                  // [{name, enabled}]
    property var clients: []                  // [{name, connected}]
    property var tools: []                    // [{name, description}]
    property var secrets: ({})                // {catalogKey: true}
    property var inspectCache: ({})           // {serverName: <detail>}
    property string currentInspect: ""        // server name shown in detail view

    property bool loadingCatalog: false
    property bool loadingServers: false
    property bool loadingClients: false
    property bool loadingTools: false
    property bool loadingInspect: false
    property bool busy: false                 // any write op in flight

    property string lastError: ""
    property string lastMessage: ""

    signal actionFinished(string verb, bool ok, string message)

    // ── helper to run a read command ─────────────────────────────
    function _parse(text) {
        try { return JSON.parse(text) }
        catch (e) { return null }
    }

    // ── catalog ──────────────────────────────────────────────────
    Process {
        id: catalogProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.loadingCatalog = false
                const j = root._parse(text)
                if (j && Array.isArray(j)) root.catalog = j
                else if (j && j.error) root.lastError = j.error
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.length > 0) console.warn("[mcp catalog]", text.trim())
        }
    }
    function refreshCatalog() {
        if (catalogProc.running) catalogProc.running = false
        catalogProc.command = [helper, "catalog"]
        root.loadingCatalog = true
        catalogProc.running = true
    }

    // ── servers (enabled) ────────────────────────────────────────
    Process {
        id: serversProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.loadingServers = false
                const j = root._parse(text)
                if (j && Array.isArray(j)) root.servers = j
                else if (j && j.error) root.lastError = j.error
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.length > 0) console.warn("[mcp servers]", text.trim())
        }
    }
    function refreshServers() {
        if (serversProc.running) serversProc.running = false
        serversProc.command = [helper, "servers"]
        root.loadingServers = true
        serversProc.running = true
    }

    // ── clients ──────────────────────────────────────────────────
    Process {
        id: clientsProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.loadingClients = false
                const j = root._parse(text)
                if (j && Array.isArray(j)) root.clients = j
                else if (j && j.error) root.lastError = j.error
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.length > 0) console.warn("[mcp clients]", text.trim())
        }
    }
    function refreshClients() {
        if (clientsProc.running) clientsProc.running = false
        clientsProc.command = [helper, "clients"]
        root.loadingClients = true
        clientsProc.running = true
    }

    // ── tools ────────────────────────────────────────────────────
    Process {
        id: toolsProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.loadingTools = false
                const j = root._parse(text)
                if (j && Array.isArray(j)) root.tools = j
                else if (j && j.error) root.lastError = j.error
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.length > 0) console.warn("[mcp tools]", text.trim())
        }
    }
    function refreshTools() {
        if (toolsProc.running) toolsProc.running = false
        toolsProc.command = [helper, "tools"]
        root.loadingTools = true
        toolsProc.running = true
    }

    // ── server inspect (per name, cached) ────────────────────────
    Process {
        id: inspectProc
        property string targetName: ""
        stdout: StdioCollector {
            onStreamFinished: {
                root.loadingInspect = false
                const j = root._parse(text)
                if (j && !j.error) {
                    const c = Object.assign({}, root.inspectCache)
                    c[inspectProc.targetName] = j
                    root.inspectCache = c
                } else if (j && j.error) {
                    root.lastError = j.error
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.length > 0) console.warn("[mcp inspect]", text.trim())
        }
    }
    function inspectServer(name, force) {
        if (!force && root.inspectCache[name]) {
            root.currentInspect = name
            return
        }
        if (inspectProc.running) inspectProc.running = false
        inspectProc.targetName = name
        inspectProc.command = [helper, "server-inspect", name]
        root.loadingInspect = true
        root.currentInspect = name
        inspectProc.running = true
    }

    // ── secrets (presence) ───────────────────────────────────────
    Process {
        id: secretsProc
        stdout: StdioCollector {
            onStreamFinished: {
                const j = root._parse(text)
                if (j && !j.error) root.secrets = j
                else if (j && j.error) root.lastError = j.error
            }
        }
    }
    function refreshSecrets() {
        if (secretsProc.running) secretsProc.running = false
        secretsProc.command = [helper, "secrets"]
        secretsProc.running = true
    }

    // Re-parse secrets on file change (no respawn — qs FileView).
    FileView {
        path: root.secretsPath
        watchChanges: true
        onFileChanged: { reload(); root.refreshSecrets() }
    }

    // ── action dispatcher (writes) ───────────────────────────────
    // Reuses one Process; serialise writes to avoid concurrent docker calls.
    Process {
        id: actionProc
        property string verb: ""
        property string outBuf: ""
        property string errBuf: ""
        stdout: StdioCollector { onStreamFinished: actionProc.outBuf = text }
        stderr: StdioCollector { onStreamFinished: actionProc.errBuf = text }
        onRunningChanged: {
            if (running) return
            root.busy = false
            const j = root._parse(actionProc.outBuf)
            const ok = !!(j && j.ok)
            const msg = j && j.message ? j.message
                       : j && j.error ? j.error
                       : actionProc.errBuf.trim()
            if (!ok && j && j.error) root.lastError = j.error
            else if (ok) { root.lastError = ""; root.lastMessage = msg }
            root.actionFinished(actionProc.verb, ok, msg)
            // Post-action refresh per verb
            switch (actionProc.verb) {
                case "server-enable":
                case "server-disable":   root.refreshServers(); root.refreshTools(); break
                case "client-connect":
                case "client-disconnect": root.refreshClients(); break
                case "secret-set":
                case "secret-rm":        root.refreshSecrets(); break
            }
        }
    }

    function _runAction(verb, args) {
        if (actionProc.running) actionProc.running = false
        actionProc.verb = verb
        actionProc.outBuf = ""
        actionProc.errBuf = ""
        actionProc.command = [helper, verb].concat(args)
        root.busy = true
        actionProc.running = true
    }

    function enableServer(name)     { _runAction("server-enable",  [name]) }
    function disableServer(name)    { _runAction("server-disable", [name]) }
    function connectClient(name)    { _runAction("client-connect",    [name]) }
    function disconnectClient(name) { _runAction("client-disconnect", [name]) }
    function setSecret(catalogKey, value) { _runAction("secret-set", [catalogKey, value]) }
    function removeSecret(catalogKey)     { _runAction("secret-rm",  [catalogKey]) }
    function ensureGatewayConfig()        { _runAction("ensure-gateway-config", []) }

    // ── batch refresh ────────────────────────────────────────────
    function refreshAll() {
        refreshCatalog()
        refreshServers()
        refreshClients()
        refreshTools()
        refreshSecrets()
    }

    Component.onCompleted: ensureGatewayConfig()
}
