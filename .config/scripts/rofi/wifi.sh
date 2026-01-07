#!/usr/bin/env bash
# WiFi Manager - Rofi script-mode compatible
# Can be used standalone OR as rofi modi

# State file for tracking connection flow
STATE_FILE="/tmp/rofi_wifi_state"

# Check if we're running inside rofi script-mode
if [[ -n "$ROFI_RETV" ]]; then
    # Called from rofi as script-mode
    SELECTED="$1"
    INFO="$ROFI_INFO"

    case "$ROFI_RETV" in
        0)
            # Initial call - show menu
            ;;
        1)
            # User selected an entry
            if [[ "$SELECTED" == "󰖩  Enable Wi-Fi" ]]; then
                nmcli radio wifi on
                notify-send "Wi-Fi" "Wi-Fi enabled" -t 2000
                exit 0
            elif [[ "$SELECTED" == "󰖪  Disable Wi-Fi" ]]; then
                nmcli radio wifi off
                notify-send "Wi-Fi" "Wi-Fi disabled" -t 2000
                exit 0
            elif [[ "$SELECTED" == "󰑓  Refresh" ]]; then
                # Just continue to show menu again
                :
            elif [[ "$SELECTED" == "  Back" ]]; then
                rm -f "$STATE_FILE"
                # Continue to show main menu
                :
            elif [[ -f "$STATE_FILE" ]] && grep -q "^PASSWORD:" "$STATE_FILE"; then
                # Password was entered
                SSID=$(grep "^SSID:" "$STATE_FILE" | cut -d: -f2-)
                PASSWORD="$SELECTED"
                rm -f "$STATE_FILE"

                # Try to connect with password
                result=$(nmcli device wifi connect "$SSID" password "$PASSWORD" 2>&1)
                if echo "$result" | grep -q "successfully"; then
                    notify-send "Wi-Fi Connected" "Connected to \"$SSID\"" -t 3000
                else
                    notify-send "Wi-Fi Error" "Failed to connect: $result" -u critical
                fi
                exit 0
            else
                # Network selected
                SSID="${SELECTED#*  }"  # Remove icon prefix
                SSID="${SSID#* }"       # Remove security icon if present
                SSID=$(echo "$SSID" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

                # Check if already saved
                saved=$(nmcli -g NAME connection)
                if echo "$saved" | grep -qxF "$SSID"; then
                    # Saved network - just connect
                    result=$(nmcli connection up id "$SSID" 2>&1)
                    if echo "$result" | grep -q "successfully"; then
                        notify-send "Wi-Fi Connected" "Connected to \"$SSID\"" -t 3000
                    else
                        notify-send "Wi-Fi Error" "Failed to connect: $result" -u critical
                    fi
                    exit 0
                else
                    # Check if network needs password (has lock icon)
                    if [[ "$SELECTED" == *""* ]]; then
                        # Need password - save state and prompt
                        echo "SSID:$SSID" > "$STATE_FILE"
                        echo "PASSWORD:1" >> "$STATE_FILE"

                        # Show password prompt
                        echo -en "\x00prompt\x1fPassword for $SSID\n"
                        echo -en "\x00message\x1fEnter password for \"$SSID\"\n"
                        echo "  Back"
                        exit 0
                    else
                        # Open network - connect directly
                        result=$(nmcli device wifi connect "$SSID" 2>&1)
                        if echo "$result" | grep -q "successfully"; then
                            notify-send "Wi-Fi Connected" "Connected to \"$SSID\"" -t 3000
                        else
                            notify-send "Wi-Fi Error" "Failed to connect: $result" -u critical
                        fi
                        exit 0
                    fi
                fi
            fi
            ;;
    esac

    # Show main menu
    rm -f "$STATE_FILE"

    # Get current WiFi state
    wifi_status=$(nmcli -fields WIFI g 2>/dev/null | tail -1)

    if [[ "$wifi_status" =~ "enabled" ]]; then
        echo "󰖪  Disable Wi-Fi"
        echo "󰑓  Refresh"
        echo ""

        # Get available networks
        # Format: SECURITY, SIGNAL, SSID
        nmcli -t -f SECURITY,SIGNAL,SSID device wifi list 2>/dev/null | while IFS=: read -r security signal ssid; do
            [[ -z "$ssid" ]] && continue

            # Signal strength icon
            if [[ "$signal" -ge 75 ]]; then
                sig_icon="󰤨"
            elif [[ "$signal" -ge 50 ]]; then
                sig_icon="󰤥"
            elif [[ "$signal" -ge 25 ]]; then
                sig_icon="󰤢"
            else
                sig_icon="󰤟"
            fi

            # Security icon
            if [[ "$security" != "" && "$security" != "--" ]]; then
                sec_icon=" "
            else
                sec_icon=""
            fi

            echo "$sig_icon$sec_icon $ssid"
        done | sort -u
    else
        echo "󰖩  Enable Wi-Fi"
    fi

    exit 0
fi

# Standalone mode - launch rofi with this script
exec rofi -show WIFI -modi "WIFI:$0" -theme "$HOME/.config/rofi/config.rasi"
