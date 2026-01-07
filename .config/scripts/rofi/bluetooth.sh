#!/usr/bin/env bash
# Bluetooth Manager - Rofi script-mode compatible
# Can be used standalone OR as rofi modi
#
# Based on rofi-bluetooth by Nick Clyde (clydedroid)
# Converted to script-mode for integration with launcher

# State file for tracking menu navigation
STATE_FILE="/tmp/rofi_bluetooth_state"

# Icons
ICON_ON="󰂯"
ICON_OFF="󰂲"
ICON_CONNECTED="󰂱"
ICON_PAIRED="󰂰"
ICON_SCAN="󰂰"
ICON_BACK="󰁍"

# Check if bluetooth controller is powered on
power_on() {
    bluetoothctl show | grep -q "Powered: yes"
}

# Check if scanning
scan_on() {
    bluetoothctl show | grep -q "Discovering: yes"
}

# Check if device is connected
device_connected() {
    bluetoothctl info "$1" 2>/dev/null | grep -q "Connected: yes"
}

# Check if device is paired
device_paired() {
    bluetoothctl info "$1" 2>/dev/null | grep -q "Paired: yes"
}

# Check if device is trusted
device_trusted() {
    bluetoothctl info "$1" 2>/dev/null | grep -q "Trusted: yes"
}

# Get device name from MAC
get_device_name() {
    bluetoothctl info "$1" 2>/dev/null | grep "Alias:" | cut -d' ' -f2-
}

# Show main menu
show_main_menu() {
    rm -f "$STATE_FILE"

    if power_on; then
        echo "$ICON_OFF  Power Off"
        echo ""

        if scan_on; then
            echo "󰍷  Stop Scan"
        else
            echo "$ICON_SCAN  Scan for Devices"
        fi
        echo ""

        # List devices
        echo "━━━ Devices ━━━"

        # Get paired devices
        local paired_cmd="devices Paired"
        # Check bluetoothctl version for compatibility
        if bluetoothctl version 2>/dev/null | grep -q "5\.[0-5]"; then
            paired_cmd="paired-devices"
        fi

        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            local mac name icon
            mac=$(echo "$line" | awk '{print $2}')
            name=$(echo "$line" | cut -d' ' -f3-)

            if device_connected "$mac"; then
                icon="$ICON_CONNECTED"
            elif device_paired "$mac"; then
                icon="$ICON_PAIRED"
            else
                icon="󰂲"
            fi

            echo "$icon  $name"
        done < <(bluetoothctl $paired_cmd 2>/dev/null | grep "Device")

        # Show discovered but not paired devices
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            local mac name
            mac=$(echo "$line" | awk '{print $2}')
            name=$(echo "$line" | cut -d' ' -f3-)

            # Skip if already paired
            if device_paired "$mac"; then
                continue
            fi

            echo "󰂲  $name"
        done < <(bluetoothctl devices 2>/dev/null | grep "Device")
    else
        echo "$ICON_ON  Power On"
    fi
}

# Show device submenu
show_device_menu() {
    local device_name="$1"
    local mac

    # Find MAC address from device name
    mac=$(bluetoothctl devices 2>/dev/null | grep "$device_name" | awk '{print $2}' | head -1)

    if [[ -z "$mac" ]]; then
        show_main_menu
        return
    fi

    # Save state
    echo "DEVICE:$mac" > "$STATE_FILE"

    echo "$ICON_BACK  Back"
    echo ""

    if device_connected "$mac"; then
        echo "󰂲  Disconnect"
    else
        echo "$ICON_CONNECTED  Connect"
    fi

    if device_paired "$mac"; then
        echo "󱋿  Unpair"
    else
        echo "$ICON_PAIRED  Pair"
    fi

    if device_trusted "$mac"; then
        echo "󰿆  Untrust"
    else
        echo "󰒘  Trust"
    fi
}

# Handle selection from main menu
handle_main_selection() {
    local selected="$1"

    case "$selected" in
        "$ICON_ON  Power On")
            if rfkill list bluetooth | grep -q 'blocked: yes'; then
                rfkill unblock bluetooth
                sleep 1
            fi
            bluetoothctl power on
            notify-send "Bluetooth" "Powered on" -t 2000
            ;;

        "$ICON_OFF  Power Off")
            bluetoothctl power off
            notify-send "Bluetooth" "Powered off" -t 2000
            ;;

        "$ICON_SCAN  Scan for Devices")
            notify-send "Bluetooth" "Scanning for devices..." -t 2000
            bluetoothctl --timeout 5 scan on &
            ;;

        "󰍷  Stop Scan")
            pkill -f "bluetoothctl.*scan" 2>/dev/null
            bluetoothctl scan off
            ;;

        "━━━"* | "")
            # Separator or empty - just refresh menu
            ;;

        "$ICON_CONNECTED  "*|"$ICON_PAIRED  "*|"󰂲  "*)
            # Device selected - show device menu
            local device_name="${selected#*  }"
            show_device_menu "$device_name"
            return 0
            ;;
    esac

    # Show main menu again
    show_main_menu
}

# Handle selection from device menu
handle_device_selection() {
    local selected="$1"
    local mac="$2"
    local device_name

    device_name=$(get_device_name "$mac")

    case "$selected" in
        "$ICON_BACK  Back")
            rm -f "$STATE_FILE"
            show_main_menu
            return 0
            ;;

        "$ICON_CONNECTED  Connect")
            notify-send "Bluetooth" "Connecting to $device_name..." -t 2000
            if bluetoothctl connect "$mac" 2>&1 | grep -q "successful"; then
                notify-send "Bluetooth" "Connected to $device_name" -t 2000
            else
                notify-send "Bluetooth" "Failed to connect to $device_name" -u critical
            fi
            ;;

        "󰂲  Disconnect")
            bluetoothctl disconnect "$mac"
            notify-send "Bluetooth" "Disconnected from $device_name" -t 2000
            ;;

        "$ICON_PAIRED  Pair")
            notify-send "Bluetooth" "Pairing with $device_name..." -t 2000
            bluetoothctl pair "$mac"
            ;;

        "󱋿  Unpair")
            bluetoothctl remove "$mac"
            notify-send "Bluetooth" "Removed $device_name" -t 2000
            rm -f "$STATE_FILE"
            show_main_menu
            return 0
            ;;

        "󰒘  Trust")
            bluetoothctl trust "$mac"
            notify-send "Bluetooth" "Trusted $device_name" -t 2000
            ;;

        "󰿆  Untrust")
            bluetoothctl untrust "$mac"
            notify-send "Bluetooth" "Untrusted $device_name" -t 2000
            ;;
    esac

    # Stay in device menu
    show_device_menu "$device_name"
}

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
            if [[ -f "$STATE_FILE" ]] && grep -q "^DEVICE:" "$STATE_FILE"; then
                # We're in device menu
                mac=$(grep "^DEVICE:" "$STATE_FILE" | cut -d: -f2)
                handle_device_selection "$SELECTED" "$mac"
            else
                # We're in main menu
                handle_main_selection "$SELECTED"
            fi
            ;;
        *)
            show_main_menu
            ;;
    esac
else
    # Standalone mode - launch rofi with this script
    rm -f "$STATE_FILE"
    exec rofi -show BLUETOOTH -modi "BLUETOOTH:$0" -theme "$HOME/.config/rofi/config.rasi"
fi

exit 0
