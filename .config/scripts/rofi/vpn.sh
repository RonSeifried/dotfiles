#!/usr/bin/env bash
# VPN Manager – multi-protocol (WireGuard + OpenVPN)
# Uses nmcli exclusively (no pkexec/sudo needed)
# Waybar integration: vpn.sh --status

THEME="$HOME/.config/rofi/utility.rasi"

# ── Icons ────────────────────────────────────────────────────────────
IC_ON="󰌾"
IC_OFF="󰌿"
IC_ADD="󰐕"
IC_RM="󰍴"
IC_EDIT="󰏫"

# ── Helpers ──────────────────────────────────────────────────────────
# List all VPN connections (WireGuard + OpenVPN via NM plugin)
# Output: "name|type" per line
list_vpns() {
    nmcli -t -f NAME,TYPE connection show 2>/dev/null \
        | awk -F: '$2 == "wireguard" || $2 == "vpn" { print $1 "|" $2 }'
}

# Check if a connection is currently active (by name, type-agnostic)
is_active() {
    nmcli -t -f NAME connection show --active 2>/dev/null | grep -qx "$1"
}

# Get all active VPN names
active_vpns() {
    nmcli -t -f NAME,TYPE connection show --active 2>/dev/null \
        | awk -F: '$2 == "wireguard" || $2 == "vpn" { print $1 }' || true
}

# Get the assigned IP for an active VPN connection
vpn_ip() {
    nmcli -g IP4.ADDRESS connection show "$1" 2>/dev/null | head -1 | cut -d/ -f1
}

# ── Waybar status output ─────────────────────────────────────────────
if [[ "${1:-}" == "--status" ]]; then
    mapfile -t vpns < <(active_vpns 2>/dev/null)
    if [[ ${#vpns[@]} -gt 0 ]]; then
        if [[ ${#vpns[@]} -eq 1 ]]; then
            ip=$(vpn_ip "${vpns[0]}")
            tooltip="VPN: ${vpns[0]}${ip:+ ($ip)}"
            text="$IC_ON"
        else
            tooltip="VPN: ${vpns[*]} (${#vpns[@]} active)"
            text="$IC_ON ${#vpns[@]}"
        fi
        echo "{\"text\": \"$text\", \"tooltip\": \"$tooltip\", \"class\": \"on\"}"
    else
        echo "{\"text\": \"$IC_OFF\", \"tooltip\": \"VPN: Off\", \"class\": \"off\"}"
    fi
    exit 0
fi

# Strict mode only for interactive menu (not waybar polling)
set -euo pipefail

# ── Build menu ───────────────────────────────────────────────────────
build_menu() {
    echo "$IC_ADD  Add VPN from file…"
    echo "$IC_RM  Remove VPN…"
    echo "$IC_EDIT  Edit VPN…"
    echo "──────────────────"

    local configs
    configs=$(list_vpns)

    if [[ -z "$configs" ]]; then
        echo "  No VPN profiles in NetworkManager"
        return
    fi

    while IFS='|' read -r name type; do
        [[ -z "$name" ]] && continue
        local badge
        case "$type" in
            wireguard) badge="WG" ;;
            vpn)       badge="OVP" ;;
            *)         badge="VPN" ;;
        esac
        if is_active "$name"; then
            local ip
            ip=$(vpn_ip "$name")
            if [[ -n "$ip" ]]; then
                echo "$IC_ON  $name  [$badge] ($ip)"
            else
                echo "$IC_ON  $name  [$badge] (connected)"
            fi
        else
            echo "$IC_OFF  $name  [$badge]"
        fi
    done <<< "$configs"
}

# ── Import VPN from file ─────────────────────────────────────────────
import_vpn_file() {
    local scan_dirs=("$HOME/Downloads" "$HOME" "$HOME/.config/vpn" "/etc/wireguard")
    local found_files=""
    for dir in "${scan_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            while IFS= read -r f; do
                found_files+="$f"$'\n'
            done < <(find "$dir" -maxdepth 1 \( -name "*.conf" -o -name "*.ovpn" \) 2>/dev/null | sort)
        fi
    done

    local options
    if [[ -n "$found_files" ]]; then
        options="${found_files}  Type path manually…"
    else
        options="  Type path manually…"
    fi

    local chosen
    chosen=$(echo "$options" | rofi -dmenu -i -p "$IC_ADD Select config file" -theme "$THEME")
    [[ -z "$chosen" ]] && return

    local filepath
    if [[ "$chosen" == *"Type path manually"* ]]; then
        filepath=$(echo "" | rofi -dmenu -p "  File path:" -theme "$THEME")
        [[ -z "$filepath" ]] && return
    else
        filepath="$chosen"
    fi

    if [[ ! -f "$filepath" ]]; then
        notify-send "VPN" "File not found: $filepath" -u critical
        return
    fi

    local import_type="wireguard"
    [[ "$filepath" == *.ovpn ]] && import_type="openvpn"

    notify-send "VPN" "Importing $(basename "$filepath")…" -t 2000
    if nmcli connection import type "$import_type" file "$filepath" 2>&1; then
        notify-send "VPN" "Imported $(basename "$filepath")" -t 2000
    else
        notify-send "VPN" "Import failed" -u critical
    fi
}

# ── Remove VPN ───────────────────────────────────────────────────────
remove_vpn() {
    local configs
    configs=$(list_vpns)
    if [[ -z "$configs" ]]; then
        notify-send "VPN" "No VPN profiles to remove" -t 2000
        return
    fi

    local names
    names=$(while IFS='|' read -r name _; do echo "$name"; done <<< "$configs")

    local chosen
    chosen=$(echo "$names" | rofi -dmenu -i -p "$IC_RM Remove VPN" -theme "$THEME")
    [[ -z "$chosen" ]] && return

    local confirm
    confirm=$(printf "Yes, delete %s\nCancel" "$chosen" \
        | rofi -dmenu -i -p "⚠ Confirm" -theme "$THEME")
    [[ "$confirm" != "Yes, delete $chosen" ]] && return

    is_active "$chosen" && nmcli connection down "$chosen" 2>/dev/null || true

    if nmcli connection delete "$chosen" 2>&1; then
        notify-send "VPN" "Removed $chosen" -t 2000
    else
        notify-send "VPN" "Failed to remove $chosen" -u critical
    fi
}

# ── Edit VPN properties ──────────────────────────────────────────────
edit_vpn_properties() {
    local name="$1"

    while true; do
        # Fetch current values fresh each iteration
        local cur_id cur_auto cur_never_def cur_dns cur_type
        cur_id=$(nmcli -g connection.id connection show "$name" 2>/dev/null)
        cur_auto=$(nmcli -g connection.autoconnect connection show "$name" 2>/dev/null)
        cur_never_def=$(nmcli -g ipv4.never-default connection show "$name" 2>/dev/null)
        cur_dns=$(nmcli -g ipv4.dns connection show "$name" 2>/dev/null)
        cur_type=$(nmcli -g connection.type connection show "$name" 2>/dev/null)
        [[ -z "$cur_dns" ]] && cur_dns="auto"

        local menu
        menu="$IC_EDIT  Name: $cur_id
$IC_EDIT  Auto-connect: $cur_auto
$IC_EDIT  Split tunnel: $cur_never_def
$IC_EDIT  DNS: $cur_dns
──────────────────
󰏻  Open in nm-connection-editor"

        local prop
        prop=$(echo "$menu" | rofi -dmenu -i -p "$IC_EDIT $cur_id" -theme "$THEME")
        [[ -z "$prop" ]] && return

        case "$prop" in
            *"Name:"*)
                local new_name
                new_name=$(echo "$cur_id" | rofi -dmenu -p "$IC_EDIT Name:" -theme "$THEME")
                [[ -z "$new_name" || "$new_name" == "$cur_id" ]] && continue
                if nmcli connection modify "$name" connection.id "$new_name" 2>&1; then
                    notify-send "VPN" "Renamed to $new_name" -t 2000
                    name="$new_name"
                else
                    notify-send "VPN" "Rename failed" -u critical
                fi
                ;;
            *"Auto-connect:"*)
                local new_val
                [[ "$cur_auto" == "yes" ]] && new_val="no" || new_val="yes"
                if nmcli connection modify "$name" connection.autoconnect "$new_val" 2>&1; then
                    notify-send "VPN" "Auto-connect: $new_val" -t 2000
                else
                    notify-send "VPN" "Failed" -u critical
                fi
                ;;
            *"Split tunnel:"*)
                local new_val
                [[ "$cur_never_def" == "yes" ]] && new_val="no" || new_val="yes"
                if nmcli connection modify "$name" \
                    ipv4.never-default "$new_val" \
                    ipv6.never-default "$new_val" 2>&1; then
                    notify-send "VPN" "Split tunnel: $new_val" -t 2000
                else
                    notify-send "VPN" "Failed" -u critical
                fi
                ;;
            *"DNS:"*)
                local new_dns
                new_dns=$(echo "$cur_dns" | rofi -dmenu -p "$IC_EDIT DNS (blank=auto, comma-sep):" -theme "$THEME")
                [[ "$new_dns" == "auto" ]] && new_dns=""
                if nmcli connection modify "$name" ipv4.dns "$new_dns" 2>&1; then
                    notify-send "VPN" "DNS updated" -t 2000
                else
                    notify-send "VPN" "Failed" -u critical
                fi
                ;;
            *"nm-connection-editor"*)
                local uuid
                uuid=$(nmcli -g connection.uuid connection show "$name" 2>/dev/null)
                if command -v nm-connection-editor &>/dev/null; then
                    nm-connection-editor --edit "$uuid" &
                else
                    notify-send "VPN" "nm-connection-editor not installed" -u critical
                fi
                return
                ;;
            "──────────────────")
                ;;
        esac
    done
}

edit_vpn() {
    local configs
    configs=$(list_vpns)
    if [[ -z "$configs" ]]; then
        notify-send "VPN" "No VPN profiles to edit" -t 2000
        return
    fi

    local names
    names=$(while IFS='|' read -r name _; do echo "$name"; done <<< "$configs")

    local chosen
    chosen=$(echo "$names" | rofi -dmenu -i -p "$IC_EDIT Edit VPN" -theme "$THEME")
    [[ -z "$chosen" ]] && return

    edit_vpn_properties "$chosen"
}

# ── Main ─────────────────────────────────────────────────────────────
chosen=$(build_menu | rofi -dmenu -i -p "󰌾 VPN" -theme "$THEME")
[[ -z "$chosen" ]] && exit 0

# Strip protocol badge + IP suffix from chosen name
strip_name() {
    local s="$1"
    s="${s#$IC_ON  }"
    s="${s#$IC_OFF  }"
    s=$(echo "$s" | sed 's/  \[.*$//')
    echo "$s"
}

case "$chosen" in
    *"Add VPN from file"*)
        import_vpn_file
        ;;
    *"Remove VPN"*)
        remove_vpn
        ;;
    *"Edit VPN"*)
        edit_vpn
        ;;
    "──────────────────" | *"No VPN profiles"*)
        exit 0
        ;;
    "$IC_ON  "*)
        name=$(strip_name "$chosen")
        notify-send "VPN" "Disconnecting from $name…" -t 2000
        if nmcli connection down "$name" 2>&1; then
            notify-send "VPN" "Disconnected from $name" -t 2000
        else
            notify-send "VPN" "Failed to disconnect" -u critical
        fi
        ;;
    "$IC_OFF  "*)
        name=$(strip_name "$chosen")
        notify-send "VPN" "Connecting to $name…" -t 2000
        if nmcli connection up "$name" 2>&1; then
            notify-send "VPN" "Connected to $name" -t 2000
        else
            notify-send "VPN" "Failed to connect" -u critical
        fi
        ;;
esac

exit 0
