#!/usr/bin/env bash
# WiFi Manager – clean rofi dmenu interface
# Features: signal bars, deduplicated SSIDs, current-connection indicator, disconnect
set -euo pipefail

THEME="$HOME/.config/rofi/utility.rasi"

# ── Helpers ──────────────────────────────────────────────────────────
signal_icon() {
    local s="$1"
    if   (( s >= 75 )); then echo "󰤨"
    elif (( s >= 50 )); then echo "󰤥"
    elif (( s >= 25 )); then echo "󰤢"
    else                     echo "󰤟"
    fi
}

# ── Gather data ──────────────────────────────────────────────────────
wifi_enabled() { [[ "$(nmcli -t -f WIFI g 2>/dev/null)" == *enabled* ]]; }

current_ssid() { nmcli -t -f active,ssid dev wifi list 2>/dev/null \
    | grep '^yes' | cut -d: -f2 | head -1; }

# Deduplicate by SSID, keep strongest signal
scan_networks() {
    nmcli -t -f SSID,SIGNAL,SECURITY device wifi list --rescan no 2>/dev/null \
        | awk -F: '
            $1 != "" {
                if (!seen[$1] || $2+0 > sig[$1]+0) {
                    seen[$1] = 1; sig[$1] = $2; sec[$1] = $3
                }
            }
            END {
                for (s in seen) print sig[s] ":" sec[s] ":" s
            }
        ' | sort -t: -k1 -rn
}

# ── Build menu ───────────────────────────────────────────────────────
build_menu() {
    local cur
    cur=$(current_ssid)

    if ! wifi_enabled; then
        echo "󰖩  Enable Wi-Fi"
        return
    fi

    # Show current connection first
    if [[ -n "$cur" ]]; then
        echo "󰖪  Disconnect ($cur)"
        echo "──────────"
    fi

    echo "󰑓  Rescan"
    echo "󰖪  Disable Wi-Fi"
    echo "──────────"

    # List networks
    while IFS=: read -r signal security ssid; do
        [[ -z "$ssid" ]] && continue
        local icon
        icon=$(signal_icon "$signal")
        local lock=""
        [[ -n "$security" && "$security" != "--" ]] && lock=" "
        # Mark current with a bullet
        local marker=""
        [[ "$ssid" == "$cur" ]] && marker=" ●"
        printf "%s%s %s  %s%%%s\n" "$icon" "$lock" "$ssid" "$signal" "$marker"
    done < <(scan_networks)
}

# ── Connect ──────────────────────────────────────────────────────────
connect_to() {
    local ssid="$1"
    # Check if we have a saved connection
    if nmcli -g NAME connection show 2>/dev/null | grep -qxF "$ssid"; then
        nmcli connection up id "$ssid" 2>&1 && \
            notify-send "Wi-Fi" "Connected to \"$ssid\"" -t 3000 || \
            notify-send "Wi-Fi" "Failed to connect" -u critical
        return
    fi
    # New network – ask for password via rofi
    local pw
    pw=$(rofi -dmenu -p "Password for $ssid" -theme "$THEME" \
         -theme-str 'entry { placeholder: "Enter password..."; }' \
         -password)
    [[ -z "$pw" ]] && return
    nmcli device wifi connect "$ssid" password "$pw" 2>&1 && \
        notify-send "Wi-Fi" "Connected to \"$ssid\"" -t 3000 || \
        notify-send "Wi-Fi" "Failed to connect" -u critical
}

# ── Main ─────────────────────────────────────────────────────────────
chosen=$(build_menu | rofi -dmenu -i -p "  Wi-Fi" -theme "$THEME")
[[ -z "$chosen" ]] && exit 0

case "$chosen" in
    "󰖩  Enable Wi-Fi")
        nmcli radio wifi on
        notify-send "Wi-Fi" "Enabled" -t 2000
        ;;
    "󰖪  Disable Wi-Fi")
        nmcli radio wifi off
        notify-send "Wi-Fi" "Disabled" -t 2000
        ;;
    "󰖪  Disconnect"*)
        wifi_iface=$(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2=="wifi"{print $1;exit}')
        nmcli device disconnect "$wifi_iface" 2>/dev/null || \
        nmcli connection down "$(current_ssid)" 2>/dev/null
        notify-send "Wi-Fi" "Disconnected" -t 2000
        ;;
    "󰑓  Rescan")
        nmcli device wifi rescan 2>/dev/null
        sleep 1
        exec "$0"  # re-launch
        ;;
    "──────────") exit 0 ;;
    *)
        # Extract SSID: strip icon prefix, strip signal suffix
        ssid=$(echo "$chosen" | sed 's/^[^ ]* *//; s/ *[0-9]*%.*$//; s/ *●$//')
        # Remove lock icon if present
        ssid="${ssid# }"
        ssid=$(echo "$ssid" | xargs)  # trim
        [[ -n "$ssid" ]] && connect_to "$ssid"
        ;;
esac

exit 0
