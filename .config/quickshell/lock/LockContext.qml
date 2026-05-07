import QtQuick
import Quickshell
import Quickshell.Services.Pam

Scope {
    id: root

    enum AuthState { Idle, Typing, Authenticating, Failed }

    signal unlocked()
    signal failed()

    property int authState: LockContext.Idle
    property int attemptCount: 0
    property string currentText: ""
    property string statusText: ""

    // Stub flag — fingerprint integration not implemented in this iteration.
    // When enabling, parallel a fprintd D-Bus client to PamContext below and
    // expose a separate authChannel ("password" | "fingerprint") in completed.
    property bool enableFingerprint: false

    onCurrentTextChanged: {
        if (currentText !== "" && authState === LockContext.Failed) {
            authState = LockContext.Typing
        } else if (currentText !== "" && authState === LockContext.Idle) {
            authState = LockContext.Typing
        } else if (currentText === "" && authState === LockContext.Typing) {
            authState = LockContext.Idle
        }
    }

    Timer {
        id: failureClearTimer
        interval: 3000
        repeat: false
        onTriggered: {
            if (root.authState === LockContext.Failed) {
                root.authState = LockContext.Idle
                root.statusText = ""
            }
        }
    }
    onAuthStateChanged: {
        if (authState === LockContext.Failed) failureClearTimer.restart()
        else failureClearTimer.stop()
    }

    function tryUnlock() {
        if (currentText === "") return
        statusText = ""
        authState = LockContext.Authenticating
        pam.start()
    }

    function resetForLock() {
        currentText = ""
        attemptCount = 0
        authState = LockContext.Idle
        statusText = ""
    }

    PamContext {
        id: pam
        configDirectory: "pam"
        config: "password.conf"

        onPamMessage: {
            if (this.responseRequired) {
                this.respond(root.currentText)
            }
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.unlocked()
                root.authState = LockContext.Idle
            } else if (result === PamResult.Error) {
                // Auth service error — do not increment counter.
                root.statusText = "Auth service error"
                root.authState = LockContext.Failed
                root.currentText = ""
            } else {
                root.attemptCount += 1
                root.statusText = "Wrong password · Attempt " + root.attemptCount
                root.authState = LockContext.Failed
                root.currentText = ""
                root.failed()
            }
        }
    }
}
