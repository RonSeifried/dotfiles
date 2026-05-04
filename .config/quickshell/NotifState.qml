pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Services.Notifications

Singleton {
    id: root

    property int unreadCount: 0
    property var notifications: []

    signal toastRequested(var notif)

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
            root.notifications.push(entry)
            root.notificationsChanged()
            root.unreadCount++
            root.toastRequested(entry)
        }
    }

    function dismiss(id) {
        const entry = root.notifications.find(n => n.id === id)
        if (entry?.notif) entry.notif.dismiss()
        root.notifications = root.notifications.filter(n => n.id !== id)
        if (root.unreadCount > 0) root.unreadCount--
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
    }
}
