#!/usr/bin/env bash
# WireGuard VPN Manager - Rofi script-mode compatible
# Can be used standalone OR as rofi modi

# State file for tracking menu navigation
STATE_FILE="/tmp/rofi_vpn_state"

# Icons
ICON_CONNECTED="󰦝"
ICON_DISCONNECTED="󰦞"
ICON_CONNECT="󰌘"
ICON_DISCONNECT="󰌙"
ICON_BACK="󰁍"

# Get list of WireGuard configs (from /etc/wireguard or nmcli)
get_wg_configs() {
    local configs=()

    # Check /etc/wireguard for .conf files (use pkexec to read as root)
    if [[ -d /etc/wireguard ]]; then
        # Try to read with pkexec, fall back to direct read
        local wg_files
        wg_files=$(pkexec ls /etc/wireguard 2>/dev/null || ls /etc/wireguard 2>/dev/null)

        while IFS= read -r file; do
            if [[ "$file" == *.conf ]]; then
                configs+=("${file%.conf}")
            fi
        done <<< "$wg_files"
    fi

    # Check NetworkManager for WireGuard connections
    while IFS=: read -r name type; do
        if [[ "$type" == "wireguard" ]]; then
            # Avoid duplicates
            local found=0
            for c in "${configs[@]}"; do
                [[ "$c" == "$name" ]] && found=1 && break
            done
            [[ $found -eq 0 ]] && configs+=("$name")
        fi
    done < <(nmcli -t -f NAME,TYPE connection show 2>/dev/null)

    printf '%s\n' "${configs[@]}"
}

# Check if a WireGuard interface is active
is_connected() {
    local name="$1"
    # Check if interface exists
    ip link show "$name" &>/dev/null && return 0
    # Also check for wg- prefix variant
    ip link show "wg-$name" &>/dev/null && return 0
    # Check nmcli active connections
    nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep -q "^$name:wireguard$" && return 0
    return 1
}

# Get currently active VPN name (for waybar)
get_active_vpn() {
    # Check active WireGuard interfaces
    for iface in $(ip -o link show type wireguard 2>/dev/null | awk -F': ' '{print $2}'); do
        echo "$iface"
        return 0
    done

    # Check nmcli for active WireGuard connections
    local active
    active=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep ":wireguard$" | cut -d: -f1 | head -1)
    if [[ -n "$active" ]]; then
        echo "$active"
        return 0
    fi

    return 1
}

# Connect to VPN
connect_vpn() {
    local name="$1"

    # Try NetworkManager first
    if nmcli -t -f NAME,TYPE connection show 2>/dev/null | grep -q "^$name:wireguard$"; then
        nmcli connection up "$name" 2>&1
        return $?
    fi

    # Fall back to wg-quick (requires sudo)
    if [[ -f "/etc/wireguard/$name.conf" ]]; then
        pkexec wg-quick up "$name" 2>&1
        return $?
    fi

    echo "Configuration not found"
    return 1
}

# Disconnect from VPN
disconnect_vpn() {
    local name="$1"

    # Try NetworkManager first
    if nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep -q "^$name:wireguard$"; then
        nmcli connection down "$name" 2>&1
        return $?
    fi

    # Fall back to wg-quick (requires sudo)
    # Check both "$name" and "wg-$name" variants
    if ip link show "$name" &>/dev/null; then
        pkexec wg-quick down "$name" 2>&1
        return $?
    elif ip link show "wg-$name" &>/dev/null; then
        pkexec wg-quick down "$name" 2>&1
        return $?
    fi

    echo "Connection not found"
    return 1
}

# Show main menu
show_main_menu() {
    rm -f "$STATE_FILE"

    local configs
    configs=$(get_wg_configs)

    if [[ -z "$configs" ]]; then
        echo "󰀦  No WireGuard configs found"
        return
    fi

    echo "━━━ WireGuard VPNs ━━━"

    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        if is_connected "$name"; then
            echo "$ICON_CONNECTED  $name (connected)"
        else
            echo "$ICON_DISCONNECTED  $name"
        fi
    done <<< "$configs"
}

# Handle selection
handle_selection() {
    local selected="$1"

    case "$selected" in
        "󰀦  No WireGuard configs found" | "━━━"*)
            # Just refresh
            show_main_menu
            return 0
            ;;

        "$ICON_CONNECTED  "*)
            # Connected VPN - disconnect
            local name="${selected#$ICON_CONNECTED  }"
            name="${name% (connected)}"

            notify-send "VPN" "Disconnecting from $name..." -t 2000
            result=$(disconnect_vpn "$name" 2>&1)
            if [[ $? -eq 0 ]]; then
                notify-send "VPN" "Disconnected from $name" -t 2000
            else
                notify-send "VPN Error" "Failed to disconnect: $result" -u critical
            fi
            ;;

        "$ICON_DISCONNECTED  "*)
            # Disconnected VPN - connect
            local name="${selected#$ICON_DISCONNECTED  }"

            notify-send "VPN" "Connecting to $name..." -t 2000
            result=$(connect_vpn "$name" 2>&1)
            if [[ $? -eq 0 ]]; then
                notify-send "VPN" "Connected to $name" -t 2000
            else
                notify-send "VPN Error" "Failed to connect: $result" -u critical
            fi
            ;;
    esac

    exit 0
}

# Waybar output mode
if [[ "$1" == "--status" ]]; then
    active=$(get_active_vpn)
    if [[ -n "$active" ]]; then
        echo "{\"text\": \"󰦝\", \"tooltip\": \"VPN: $active\", \"class\": \"connected\"}"
    else
        echo "{\"text\": \"󰦞\", \"tooltip\": \"VPN: Disconnected\", \"class\": \"disconnected\"}"
    fi
    exit 0
fi

# Main logic
if [[ -n "${ROFI_RETV:-}" ]]; then
    # Running inside rofi script-mode
    SELECTED="$1"

    case "$ROFI_RETV" in
        0)
            # Initial call - show main menu
            show_main_menu
            ;;
        1)
            # User selected an entry
            handle_selection "$SELECTED"
            show_main_menu
            ;;
        *)
            show_main_menu
            ;;
    esac
else
    # Standalone mode - launch rofi with this script
    rm -f "$STATE_FILE"
    exec rofi -show VPN -modi "VPN:$0" -theme "$HOME/.config/rofi/config.rasi"
fi

exit 0
