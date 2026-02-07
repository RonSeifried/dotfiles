#!/usr/bin/env bash
# WireGuard VPN Manager – clean rofi dmenu interface
# Uses nmcli exclusively (no pkexec/sudo needed)
# Waybar integration: vpn.sh --status

THEME="$HOME/.config/rofi/utility.rasi"

# ── Icons ────────────────────────────────────────────────────────────
IC_ON="󰌾"
IC_OFF="󰌿"

# ── Helpers ──────────────────────────────────────────────────────────
# List all WireGuard connections known to NetworkManager
list_wg() {
    nmcli -t -f NAME,TYPE connection show 2>/dev/null \
        | awk -F: '$2 == "wireguard" { print $1 }'
}

# Check if a connection is currently active
is_active() {
    nmcli -t -f NAME,TYPE connection show --active 2>/dev/null \
        | grep -qx "$1:wireguard"
}

# Get first active VPN name
active_vpn() {
    nmcli -t -f NAME,TYPE connection show --active 2>/dev/null \
        | awk -F: '$2 == "wireguard" { print $1; exit }' || true
}

# ── Waybar status output ─────────────────────────────────────────────
if [[ "${1:-}" == "--status" ]]; then
    vpn=$(active_vpn 2>/dev/null) || vpn=""
    if [[ -n "$vpn" ]]; then
        echo "{\"text\": \"$IC_ON\", \"tooltip\": \"VPN: $vpn\", \"class\": \"on\"}"
    else
        echo "{\"text\": \"$IC_OFF\", \"tooltip\": \"VPN: Off\", \"class\": \"off\"}"
    fi
    exit 0
fi

# Strict mode only for interactive menu (not waybar polling)
set -euo pipefail

# ── Build menu ───────────────────────────────────────────────────────
build_menu() {
    local configs
    configs=$(list_wg)

    if [[ -z "$configs" ]]; then
        echo "  No WireGuard profiles in NetworkManager"
        echo ""
        echo "  Import: nmcli connection import type wireguard file /path/to.conf"
        return
    fi

    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        if is_active "$name"; then
            echo "$IC_ON  $name  (connected)"
        else
            echo "$IC_OFF  $name"
        fi
    done <<< "$configs"
}

# ── Main ─────────────────────────────────────────────────────────────
chosen=$(build_menu | rofi -dmenu -i -p "󰌾 VPN" -theme "$THEME")
[[ -z "$chosen" ]] && exit 0

case "$chosen" in
    *"No WireGuard"* | *"Import:"*)
        exit 0
        ;;
    "$IC_ON  "*)
        # Active → disconnect
        name="${chosen#$IC_ON  }"
        name="${name%  (connected)}"
        notify-send "VPN" "Disconnecting from $name…" -t 2000
        if nmcli connection down "$name" 2>&1; then
            notify-send "VPN" "Disconnected from $name" -t 2000
        else
            notify-send "VPN" "Failed to disconnect" -u critical
        fi
        ;;
    "$IC_OFF  "*)
        # Inactive → connect
        name="${chosen#$IC_OFF  }"
        notify-send "VPN" "Connecting to $name…" -t 2000
        if nmcli connection up "$name" 2>&1; then
            notify-send "VPN" "Connected to $name" -t 2000
        else
            notify-send "VPN" "Failed to connect" -u critical
        fi
        ;;
esac

exit 0
