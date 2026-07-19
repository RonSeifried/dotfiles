pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../settings"

Singleton {
    id: root
    property bool autoPerformance: SettingsState.autoPerformanceOnAc
    property real sourceWatts: 0
    property bool suitableSource: sourceWatts >= SettingsState.suitableChargerWatts
    property bool _applied: false
    Process {
        id: probe
        command: ["sh", "-c", "best=0; for d in /sys/class/power_supply/*; do [ -r \"$d/online\" ] || continue; [ \"$(cat \"$d/online\")\" = 1 ] || continue; w=0; for f in power_now input_power_limit; do [ -r \"$d/$f\" ] && w=$(cat \"$d/$f\") && break; done; if [ \"$w\" = 0 ] && [ -r \"$d/voltage_max\" ] && [ -r \"$d/current_max\" ]; then w=$(( $(cat \"$d/voltage_max\") * $(cat \"$d/current_max\") / 1000000 )); fi; [ \"$w\" -gt \"$best\" ] 2>/dev/null && best=$w; done; awk -v w=\"$best\" 'BEGIN { printf \"%.1f\\n\", w/1000000 }'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const watts = parseFloat(text.trim())
                root.sourceWatts = isNaN(watts) ? 0 : watts
                root._evaluate()
            }
        }
    }
    // Charger identity rarely changes. Only probe while the automation is in
    // use; this removes a shell/sysfs scan every eight seconds for everyone
    // who leaves the feature off.
    Timer { interval: 30000; repeat: true; running: root.autoPerformance; triggeredOnStart: true; onTriggered: if (!probe.running) probe.running = true }

    function setAutoPerformance(on) {
        SettingsState.autoPerformanceOnAc = on
        SettingsState.save()
        if (on && !probe.running) probe.running = true
        _evaluate()
    }
    function _evaluate() {
        if (autoPerformance && suitableSource && PowerProfiles.hasPerformanceProfile) {
            if (PowerProfiles.profile !== 2) PowerProfiles.profile = 2
            _applied = true
        } else if (_applied) {
            if (PowerProfiles.profile === 2) PowerProfiles.profile = 1
            _applied = false
        }
    }
}
