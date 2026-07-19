import QtQuick
import Quickshell
import ".."
import "../components"

GlassSurface {
    id: root
    level: "e1"; radius: Theme.radiusPill
    interactive: ActivityState.recording
    accessibleName: ActivityState.recording ? "Stop screen recording" : "Live activity"
    implicitHeight: Theme.pillHeight
    implicitWidth: ActivityState.active ? content.implicitWidth + 18 : 0
    opacity: ActivityState.active ? 1 : 0
    visible: implicitWidth > 1
    clip: true
    onClicked: if (ActivityState.recording) ActivityState.stopRecording()
    Behavior on implicitWidth { NumberAnimation { duration: Theme.durSlide; easing.type: Easing.OutCubic } }

    SystemClock { id: tick; precision: SystemClock.Seconds }
    Row {
        id: content; anchors.centerIn: parent; spacing: Theme.spacingSmall
        Rectangle {
            width: 7; height: 7; radius: 4; color: Colors.error
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: {
                if (!ActivityState.recording) {
                    const keys = Object.keys(ActivityState.external)
                    return keys.length ? ActivityState.external[keys[0]].label : ""
                }
                const total = Math.max(0, Math.floor((tick.date.getTime() - ActivityState.recordingStarted) / 1000))
                const m = Math.floor(total / 60), s = total % 60
                return "Recording  " + m + ":" + String(s).padStart(2, "0")
            }
            color: Colors.text; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily
            font.features: { "tnum": 1 }
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
