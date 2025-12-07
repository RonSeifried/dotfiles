// ~/.config/quickshell/shell.qml
// Quickshell 0.2.x – einfache Waybar-Alternative in einem Panel

import QtQuick 2.15
import QtQuick.Layouts 1.15
import Quickshell 0.2
import Quickshell.Io 0.2

// ----------------------------- helpers -----------------------------
pragma Singleton
QtObject {
    id: Util
    function bash(cmd, onDone) {
        // ad-hoc Prozess mit Ausgabe-Sammler
        var p = Qt.createQmlObject('import Quickshell.Io 0.2; Process { command: ["bash","-lc", ' + JSON.stringify(cmd) + ']; running: true; stdout: StdioCollector {} }', shell);
        p.stdout.onStreamFinished.connect(function() {
            var out = p.stdout.text.trim();
            if (onDone) onDone(out);
            p.destroy();
        });
    }
    function icon(txt, size, col) {
        return Qt.createQmlObject(
            'import QtQuick 2.15; Text { text: ' + JSON.stringify(txt) +
            '; font.pixelSize: ' + size +
            '; color: ' + JSON.stringify(col || "#eaeaea") +
            '; font.family: "JetBrainsMono Nerd Font"; font.bold: false; }', shell);
    }
}

// ----------------------------- panel -----------------------------
PanelWindow {
    id: shell
    anchors { top: true; left: true; right: true }
    implicitHeight: 54
    radius: 18
    color: "#121418cc"              // leicht transparent
    border.color: "#00000000"

    // sanfte Innenabstände
    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 14

        // -------- Power Button --------
        Rectangle {
            Layout.preferredWidth: 42
            Layout.preferredHeight: 42
            radius: width/2
            color: "#3B5BAAff"
            Text { anchors.centerIn: parent; text: "\uf011"; // nf-md-power
                   color: "#dce3f5"; font.pixelSize: 20; font.family: "JetBrainsMono Nerd Font" }
            MouseArea {
                anchors.fill: parent
                onClicked: Util.bash("command -v wlogout >/dev/null && wlogout || swaynag -t warning -m 'Power?' -B 'poweroff:systemctl poweroff' -B 'reboot:systemctl reboot'");
            }
            ToolTip.visible: containsMouse
            ToolTip.text: "Power Menu"
        }

        // -------- Uhr + Datum (Klick → Kalender) --------
        Rectangle {
            color: "#00000000"; radius: 10
            Layout.preferredWidth: 280
            Layout.alignment: Qt.AlignVCenter
            Row {
                anchors.fill: parent; anchors.margins: 6; spacing: 8
                Text {
                    id: clockText
                    text: Qt.formatDate(new Date(), "dd.MM.yyyy") + "  |  " + Qt.formatTime(new Date(), "HH:mm")
                    color: "#e7ebf0"; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font"
                }
                Timer {
                    interval: 1000; running: true; repeat: true
                    onTriggered: clockText.text = Qt.formatDate(new Date(), "dd.MM.yyyy") + "  |  " + Qt.formatTime(new Date(), "HH:mm")
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: Util.bash("command -v gsimplecal >/dev/null && gsimplecal || (command -v gnome-calendar >/dev/null && gnome-calendar) || kitty -e bash -lc 'cal -m | less'");
            }
            ToolTip.visible: containsMouse
            ToolTip.text: "Kalender öffnen"
        }

        // -------- Workspaces (Hyprland) --------
        Rectangle {
            color: "#00000000"
            Layout.fillWidth: true
            Row {
                id: wsRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                // 1..8 als Bubbles
                Repeater {
                    model: 8
                    delegate: Rectangle {
                        width: 28; height: 28; radius: width/2
                        color: (index+1) === wsModel.active ? "#3B5BAA" : "#2A2D34"
                        border.color: "#00000000"
                        Text {
                            anchors.centerIn: parent
                            text: "\ue402" // nf-linux-hyprland or simple dot: "•"
                            color: (index+1) === wsModel.active ? "#eaf1ff" : "#d0d3d9"
                            font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font"
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: Util.bash("hyprctl dispatch workspace " + (index+1));
                        }
                    }
                }

                // simples Model: pollt active workspace jede 600ms
                QtObject {
                    id: wsModel
                    property int active: 1
                    Timer {
                        interval: 600; running: true; repeat: true
                        onTriggered: Util.bash("hyprctl -j activeworkspace | sed -n 's/.*\"id\":\\s*\\([0-9]\\+\\).*/\\1/p'", function(out) {
                            var n = parseInt(out || "1"); if (!isNaN(n)) wsModel.active = n;
                        });
                    }
                }
            }
        }

        // -------- Audio (PipeWire) --------
        Rectangle {
            color: "#00000000"
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Text { id: volIcon; text: "\uf028"; color: "#e7ebf0"; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font" }
                Text { id: volText; text: "0%"; color: "#e7ebf0"; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font" }
                Timer {
                    interval: 800; running: true; repeat: true
                    onTriggered: Util.bash("wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}'", function(p){ volText.text = (p||"0") + "%"; });
                }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    onWheel: (wheel.angleDelta.y > 0)
                        ? Util.bash("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+")
                        : Util.bash("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-");
                    onClicked: { if (mouse.button === Qt.MiddleButton) Util.bash("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"); }
                    ToolTip.visible: containsMouse
                    ToolTip.text: "Lautstärke: Scroll / Mute: Middle-Click"
                }
            }
        }

        // -------- Mic mute (optional) --------
        Rectangle {
            color: "#00000000"
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Text { text: "\uf130"; color: "#e7ebf0"; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font" }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    onClicked: Util.bash("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle");
                    ToolTip.visible: containsMouse
                    ToolTip.text: "Mic mute toggle"
                }
            }
        }

        // -------- WLAN --------
        Rectangle {
            color: "#00000000"
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Text { id: wifiIcon; text: "\uf1eb"; color: "#e7ebf0"; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font" }
                Text { id: wifiText; text: "--%"; color: "#e7ebf0"; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font" }
                Timer {
                    interval: 3000; running: true; repeat: true
                    onTriggered: Util.bash("nmcli -t -f IN-USE,SSID,SIGNAL dev wifi | awk -F: '/^\\*/{print $2\" \"$3}'", function(out){
                        if (!out) { wifiText.text = "offline"; return; }
                        var parts = out.split(' ');
                        wifiText.text = (parts[0] || "") + " " + (parts[1] || "") + "%";
                    });
                }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    onClicked: Util.bash("command -v nm-connection-editor >/dev/null && nm-connection-editor || kitty -e nmtui");
                    ToolTip.visible: containsMouse
                    ToolTip.text: "WLAN verwalten"
                }
            }
        }

        // -------- Bluetooth (optional Symbol) --------
        Rectangle {
            color: "#00000000"
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Text { text: "\uf293"; color: "#e7ebf0"; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font" }
            }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true
                onClicked: Util.bash("blueman-manager || blueberry || true");
                ToolTip.visible: containsMouse
                ToolTip.text: "Bluetooth"
            }
        }

        // -------- Akku --------
        Rectangle {
            color: "#00000000"
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Text { id: batIcon; text: "\uf240"; color: "#e7ebf0"; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font" }
                Text { id: batText; text: "--%"; color: "#e7ebf0"; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font" }
                Timer {
                    interval: 15000; running: true; repeat: true
                    onTriggered: Util.bash("for b in /sys/class/power_supply/BAT*/capacity; do cat \"$b\" && break; done", function(out){ batText.text = (out||"--") + "%"; });
                }
            }
        }

        // -------- Notifications (swaync) --------
        Rectangle {
            color: "#00000000"
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Text { text: "\uf0f3"; color: "#e7ebf0"; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font" } // bell
            }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true
                onClicked: Util.bash("swaync-client -t");
                ToolTip.visible: containsMouse
                ToolTip.text: "Benachrichtigungs-Center"
            }
        }
    }
}
