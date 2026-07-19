pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../notifications"
import "../control"
import "../brightness"
import "../power"

Singleton {
    id: root
    property string activeScene: "off"
    property var previousState: null

    readonly property var scenes: [
        { id: "work", label: "Work", icon: "󰢹", detail: "Quiet, balanced, awake" },
        { id: "presentation", label: "Present", icon: "󰐩", detail: "Bright, quiet, awake" },
        { id: "movie", label: "Movie", icon: "󰿎", detail: "Dim, quiet, awake" },
        { id: "winddown", label: "Wind Down", icon: "󰖔", detail: "Warm, dim, efficient" }
    ]

    function apply(scene) {
        if (scene === "off") {
            if (previousState) {
                NotifState.setDnd(previousState.dnd)
                ControlState.idleInhibited = previousState.idleInhibited
                NightLightState.setTemp(previousState.temperature)
                if (BrightnessState.available) BrightnessState.set(previousState.brightness)
                PowerProfiles.profile = previousState.powerProfile
            }
            previousState = null
            activeScene = "off"
            return
        }
        if (!["work", "presentation", "movie", "winddown"].includes(scene)) return
        if (activeScene === "off" || !previousState) {
            previousState = ({
                dnd: NotifState.dnd,
                idleInhibited: ControlState.idleInhibited,
                temperature: NightLightState.temperature,
                brightness: BrightnessState.value,
                powerProfile: PowerProfiles.profile
            })
        }
        activeScene = scene
        NotifState.setDnd(true)
        if (scene === "work") {
            ControlState.idleInhibited = true
            NightLightState.disable()
            PowerProfiles.profile = 1
        } else if (scene === "presentation") {
            ControlState.idleInhibited = true
            NightLightState.disable()
            if (BrightnessState.available) BrightnessState.set(1.0)
            PowerProfiles.profile = 1
        } else if (scene === "movie") {
            ControlState.idleInhibited = true
            NightLightState.disable()
            if (BrightnessState.available) BrightnessState.set(0.55)
            PowerProfiles.profile = 1
        } else if (scene === "winddown") {
            ControlState.idleInhibited = false
            NightLightState.setTemp(3000)
            if (BrightnessState.available) BrightnessState.set(0.35)
            PowerProfiles.profile = 0
        }
    }
}
