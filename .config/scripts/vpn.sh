#!/usr/bin/env bash
# VPN status script for Waybar
# Outputs JSON format for waybar custom module

INTERFACE="Wireguard"

# Check if WireGuard interface is up
if ip link show "$INTERFACE" &>/dev/null; then
    # Get the endpoint IP if available
    endpoint=$(sudo wg show "$INTERFACE" endpoints 2>/dev/null | awk '{print $2}' | cut -d: -f1)

    if [[ -n "$endpoint" ]]; then
        echo "{\"text\": \"󰌾\", \"tooltip\": \"VPN: Connected\\nEndpoint: $endpoint\", \"class\": \"connected\"}"
    else
        echo "{\"text\": \"󰌾\", \"tooltip\": \"VPN: Connected\", \"class\": \"connected\"}"
    fi
else
    echo "{\"text\": \"󰦞\", \"tooltip\": \"VPN: Disconnected\", \"class\": \"disconnected\"}"
fi
