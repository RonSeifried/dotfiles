import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

PanelWindow {
    id: bar
    anchors { top: true; left: true; right: true }
    implicitHeight: 54
    radius: 18
    color: "#121418cc"

    // ---- kleine Helper als Methoden des Root-Items ----
    function sh(cmd, cb) {
        const code = `
            import Quickshell.Io 0.2
            Process {
              command: ["bash","-lc", ${JSON.stringify(cmd)}]
              running: true
              stdout: StdioCollector {}
            }`;
        const p = Qt.createQmlObject(code, bar);
        p.stdout.onStreamFinished.connect(function () {
            const out = p.stdout.text.trim();
            if (cb) cb(out);
            p.destroy();
        });
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 14

        // ---------- Power ----------
        Rectangle {
            Layout.preferredWidth: 42
            Layout.preferredHeight: 42
            radius: width/2
            color: "#3B5BAAff"
            Text {
                anchors.centerIn: parent
                text: "\uf011"         // power icon (Nerd Font)
                color: "#dce3f5"
                font.pixelSize: 20
                font.family: "JetBrainsMono Nerd Font"
            }
            MouseArea {
                anchors.fill: parent
                onClicked: bar.sh("command -v wlogout >/dev/null && wlogout || swaynag -t warning -m 'Power?' -B 'poweroff:systemctl poweroff' -B 'reboot:systemctl reboot'");
            }
        }

        // ---------- Datum/Uhr (Klick -> Kalender) ----------
        Rectangle {
            color: "transparent"
            Layout.preferredWidth: 280
            Row {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 8
                Text {
                    id: clock
                    color: "#e7ebf0"
                    font.pixelSize: 18
                    font.family: "JetBrainsMono Nerd Font"
                    text: Qt.formatDate(new Date(), "dd.MM.yyyy") + "  |  " + Qt.formatTime(new Date(), "HH:mm")
                }
                Timer {
                    interval: 1000; running: true; repeat: true
                    onTriggered: clock.text = Qt.formatDate(new Date(), "dd.MM.yyyy") + "  |  " + Qt.formatTime(new Date(), "HH:mm")
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: bar.sh("command -v gsimplecal >/dev/null && gsimplecal || (command -v gnome-calendar >/dev/null && gnome-calendar) || kitty -e bash -lc 'cal -m | less'");
            }
        }

        // ---------- Workspaces (Hyprland) ----------
        Rectangle {
            color: "transparent"
            Layout.fillWidth: true
            Row {
                id: wsRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Repeater {
                    model: 8
                    delegate: Rectangle {
                        width: 28; height: 28; radius: width/2
                        color: (index+1) === wsModel.active ? "#3B5BAA" : "#2A2D34"
                        Text {
                            anchors.centerIn: parent
                            text: "•"
                            color: (index+1) === wsModel.active ? "#eaf1ff" : "#d0d3d9"
                            font.pixelSize: 18
                            font.family: "JetBrainsMono Nerd Font"
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: bar.sh("hyprctl dispatch workspace " + (index+1));
                        }
                    }
                }

                QtObject {
                    id: wsModel
                    property int active: 1
                    Timer {
                        interval: 600; running: true; repeat: true
                        onTriggered: bar.sh("hyprctl -j activeworkspace | sed -n 's/.*\"id\":\\s*\\([0-9]\\+\\).*/\\1/p'", function(out) {
                            var n = parseInt(out || "1"); if (!isNaN(n)) wsModel.active = n;
                        });
                    }
                }
            }
        }

        // ---------- Audio ----------
        Row {
            spacing: 8
            Text { text: "\uf028"; color: "#e7ebf0"; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font" }
            Text { id: vol; text: "0%"; color: "#e7ebf0"; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font" }
            Timer {
                interval: 800; running: true; repeat: true
                onTriggered: bar.sh("wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}'", function(p){ vol.text = (p||"0") + "%"; });
            }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true
                onWheel: (wheel.angleDelta.y > 0)
                    ? bar.sh("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+")
                    : bar.sh("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-");
                onClicked: { if (mouse.button === Qt.MiddleButton) bar.sh("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"); }
            }
        }

        // ---------- WLAN ----------
        Row {
            spacing: 8
            Text { text: "\uf1eb"; color: "#e7ebf0"; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font" }
            Text { id: wifi; text: "--%"; color: "#e7ebf0"; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font" }
            Timer {
                interval: 3000; running: true; repeat: true
                onTriggered: bar.sh("nmcli -t -f IN-USE,SSID,SIGNAL dev wifi | awk -F: '/^\\*/{print $2\" \"$3}'", function(out){
                    if (!out) { wifi.text = "offline"; return; }
                    var parts = out.split(' ');
                    wifi.text = (parts[0] || "") + " " + (parts[1] || "") + "%";
                });
            }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true
                onClicked: bar.sh("command -v nm-connection-editor >/dev/null && nm-connection-editor || kitty -e nmtui");
            }
        }

        // ---------- Akku ----------
        Row {
            spacing: 8
            Text { text: "\uf240"; color: "#e7ebf0"; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font" }
            Text { id: bat; text: "--%"; color: "#e7ebf0"; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font" }
            Timer {
                interval: 15000; running: true; repeat: true
                onTriggered: bar.sh("for b in /sys/class/power_supply/BAT*/capacity; do cat \"$b\" && break; done", function(out){ bat.text = (out||\"--\") + \"%\"; });
            }
        }

        // ---------- Notifications (swaync) ----------
        Row {
            spacing: 6
            Text { text: "\uf0f3"; color: "#e7ebf0"; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font" }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true
                onClicked: bar.sh("swaync-client -t");
            }
        }
    }
}
