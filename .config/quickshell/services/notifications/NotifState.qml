pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Services.Notifications
import Quickshell.Io
import "../.."

Singleton {
    id: root

    property int unreadCount: 0
    property var notifications: []
    property int historyTick: 0
    readonly property string historyPath: (Quickshell.env("HOME") || "") + "/.local/state/quickshell/notifications.json"
    readonly property string helperPath: (Quickshell.env("HOME") || "") + "/.config/quickshell/services/settings/settings-helper.py"
    readonly property var visibleNotifications: {
        const tick = historyTick
        const now = Date.now()
        return notifications.filter(n => !n.snoozedUntil || n.snoozedUntil <= now)
    }

    // Do Not Disturb. Suppresses on-screen popups; history/unread still recorded.
    property bool dnd: false
    property var mutedApps: []
    property bool _historyLoaded: false
    property bool _pendingHistorySave: false
    property bool _deleteAfterWriter: false
    property var _diskHistory: null

    Timer { interval: 60000; repeat: true; running: true; onTriggered: root.historyTick++ }
    Timer { id: saveDelay; interval: 180; onTriggered: root._saveHistory() }
    Process {
        id: historyWriter
        property string pendingInput: ""
        stdinEnabled: true
        onStarted: {
            if (pendingInput.length > 0) {
                write(pendingInput)
                pendingInput = ""
            }
        }
        onExited: {
            if (root._deleteAfterWriter) {
                root._deleteAfterWriter = false
                root._runHistoryDelete()
                return
            }
            if (root._pendingHistorySave) {
                root._pendingHistorySave = false
                Qt.callLater(() => root._saveHistory())
            }
        }
    }
    Process { id: historyDeleter }
    FileView {
        path: root.historyPath
        onLoaded: {
            try {
                root._diskHistory = JSON.parse(text())
            } catch (e) { console.warn("NotifState: invalid history:", e) }
            if (SettingsState.loaded) root._finishHistoryLoad()
        }
        onLoadFailed: {
            root._diskHistory = ({})
            if (SettingsState.loaded) root._finishHistoryLoad()
        }
    }

    Connections {
        target: SettingsState
        function onLoadedChanged() {
            if (SettingsState.loaded && !root._historyLoaded && root._diskHistory !== null)
                root._finishHistoryLoad()
        }
        function onNotificationHistoryChanged() {
            if (!SettingsState.loaded || !root._historyLoaded) return
            if (!SettingsState.notificationHistory) root._disableHistory()
            else root._scheduleSave()
        }
    }

    signal toastRequested(var notif)

    // Reset unread badge when the Control Center opens (the notification deck
    // lives inside it — seeing the CC means seeing the notifications).
    Connections {
        target: ControlState
        function onControlCenterOpenChanged() {
            if (ControlState.controlCenterOpen) root.unreadCount = 0
        }
    }

    NotificationServer {
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true

        onNotification: notif => {
            // Track the notif so action.invoke() and notif.dismiss() stay valid
            // after this handler returns.
            notif.tracked = true
            const entry = {
                id: notif.id,
                appName: notif.appName,
                summary: notif.summary,
                body: notif.body,
                urgency: notif.urgency,
                timeout: notif.expireTimeout,
                timestamp: Date.now(),
                notif: notif,
                actions: notif.actions
            }
            entry.snoozedUntil = 0
            root.notifications = [...root.notifications, entry].slice(-100)
            root._scheduleSave()
            const quiet = root.isAppMuted(entry.appName)
            if (!ControlState.controlCenterOpen && !quiet) root.unreadCount++
            if (!root.dnd && !quiet) root.toastRequested(entry)
        }
    }

    function dismiss(id) {
        const entry = root.notifications.find(n => n.id === id)
        if (entry && entry.notif) entry.notif.dismiss()
        root.notifications = root.notifications.filter(n => n.id !== id)
        root._scheduleSave()
    }

    function invokeAction(id, action) {
        if (!action) return
        action.invoke()
        // Per FDO spec, invoking an action implies dismissal.
        dismiss(id)
    }

    function clearAll() {
        for (const n of root.notifications) {
            if (n.notif) n.notif.dismiss()
        }
        root.notifications = []
        root.unreadCount = 0
        root._scheduleSave()
    }

    function isAppMuted(name) { return mutedApps.indexOf(name || "") !== -1 }
    function toggleAppMuted(name) {
        if (!name) return
        mutedApps = isAppMuted(name)
            ? mutedApps.filter(x => x !== name)
            : mutedApps.concat([name])
        _scheduleSave()
    }

    function snooze(id, minutes) {
        const until = Date.now() + Math.max(1, minutes) * 60000
        notifications = notifications.map(n => n.id === id ? Object.assign({}, n, { snoozedUntil: until }) : n)
        historyTick++
        _scheduleSave()
    }

    function setDnd(on) { dnd = on; _scheduleSave() }

    function _finishHistoryLoad() {
        if (_historyLoaded) return
        const data = _diskHistory || ({})
        if (SettingsState.notificationHistory) {
            root.dnd = data.dnd || false
            root.mutedApps = data.mutedApps || []
            const cutoff = Date.now() - 7 * 86400000
            root.notifications = (data.notifications || [])
                .filter(n => n.timestamp >= cutoff).slice(-100)
        } else {
            root._deleteHistoryFile()
        }
        root._diskHistory = null
        root._historyLoaded = true
    }

    function _deleteHistoryFile() {
        if (historyWriter.running) {
            _deleteAfterWriter = true
            historyWriter.running = false
        } else {
            _runHistoryDelete()
        }
        historyWriter.pendingInput = ""
    }

    function _runHistoryDelete() {
        historyDeleter.command = ["python3", helperPath, "delete", historyPath]
        historyDeleter.running = true
    }

    function _disableHistory() {
        saveDelay.stop()
        _pendingHistorySave = false
        // Keep notifications received by this live shell, but discard restored
        // disk-only entries and remove their backing file immediately.
        notifications = notifications.filter(n => !!n.notif)
        _deleteHistoryFile()
    }

    function _serializable() {
        return notifications.map(n => ({
            id: n.id, appName: n.appName || "", summary: n.summary || "", body: n.body || "",
            urgency: n.urgency || 0, timeout: n.timeout || 0, timestamp: n.timestamp || Date.now(),
            snoozedUntil: n.snoozedUntil || 0, actions: []
        }))
    }
    function _scheduleSave() { if (_historyLoaded && SettingsState.notificationHistory) saveDelay.restart() }
    function _saveHistory() {
        if (!SettingsState.notificationHistory) return
        if (historyWriter.running) { _pendingHistorySave = true; return }
        const data = { schemaVersion: 1, dnd, mutedApps, notifications: _serializable() }
        historyWriter.pendingInput = JSON.stringify(data)
        historyWriter.command = ["python3", helperPath, "write-stdin", historyPath]
        historyWriter.running = true
    }
}
