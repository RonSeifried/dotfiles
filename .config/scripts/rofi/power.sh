#!/usr/bin/env bash
# Power Menu - Rofi script-mode compatible
# Provides shutdown, reboot, logout, lock, and suspend options

# Icons
ICON_LOCK="󰌾"
ICON_LOGOUT="󰍃"
ICON_SUSPEND="󰤄"
ICON_REBOOT="󰜉"
ICON_SHUTDOWN="󰐥"
ICON_CANCEL="󰜺"

# Menu options
OPTIONS="$ICON_LOCK  Lock
$ICON_LOGOUT  Logout
$ICON_SUSPEND  Suspend
$ICON_REBOOT  Reboot
$ICON_SHUTDOWN  Shutdown"

# Confirmation menu
confirm_action() {
    local action="$1"
    echo "$ICON_CANCEL  Cancel"
    echo "  Yes, $action"
}

# Execute action
execute_action() {
    local action="$1"

    case "$action" in
        "lock")
            # Try various lock commands
            if command -v hyprlock &>/dev/null; then
                hyprlock
            elif command -v swaylock &>/dev/null; then
                swaylock -f
            elif command -v loginctl &>/dev/null; then
                loginctl lock-session
            fi
            ;;
        "logout")
            if command -v hyprctl &>/dev/null; then
                hyprctl dispatch exit
            elif command -v swaymsg &>/dev/null; then
                swaymsg exit
            elif command -v loginctl &>/dev/null; then
                loginctl terminate-user "$USER"
            fi
            ;;
        "suspend")
            systemctl suspend
            ;;
        "reboot")
            systemctl reboot
            ;;
        "shutdown")
            systemctl poweroff
            ;;
    esac
}

# State file for confirmation
STATE_FILE="/tmp/rofi_power_state"

# Main logic
if [[ -n "${ROFI_RETV:-}" ]]; then
    # Running inside rofi script-mode
    SELECTED="$1"

    case "$ROFI_RETV" in
        0)
            # Initial call - show main menu
            rm -f "$STATE_FILE"
            echo -e "$OPTIONS"
            ;;
        1)
            # User selected an entry
            if [[ -f "$STATE_FILE" ]]; then
                # We're in confirmation menu
                action=$(cat "$STATE_FILE")
                rm -f "$STATE_FILE"

                if [[ "$SELECTED" == "  Yes, "* ]]; then
                    execute_action "$action"
                    exit 0
                else
                    # Cancelled - show main menu
                    echo -e "$OPTIONS"
                fi
            else
                # Main menu selection
                case "$SELECTED" in
                    "$ICON_LOCK  Lock")
                        execute_action "lock"
                        exit 0
                        ;;
                    "$ICON_LOGOUT  Logout")
                        echo "logout" > "$STATE_FILE"
                        echo -en "\x00prompt\x1fLogout?\n"
                        confirm_action "logout"
                        ;;
                    "$ICON_SUSPEND  Suspend")
                        execute_action "suspend"
                        exit 0
                        ;;
                    "$ICON_REBOOT  Reboot")
                        echo "reboot" > "$STATE_FILE"
                        echo -en "\x00prompt\x1fReboot?\n"
                        confirm_action "reboot"
                        ;;
                    "$ICON_SHUTDOWN  Shutdown")
                        echo "shutdown" > "$STATE_FILE"
                        echo -en "\x00prompt\x1fShutdown?\n"
                        confirm_action "shutdown"
                        ;;
                    *)
                        echo -e "$OPTIONS"
                        ;;
                esac
            fi
            ;;
        *)
            rm -f "$STATE_FILE"
            echo -e "$OPTIONS"
            ;;
    esac
else
    # Standalone mode - launch rofi with this script
    rm -f "$STATE_FILE"
    exec rofi -show POWER -modi "POWER:$0" -theme "$HOME/.config/rofi/config.rasi" \
        -theme-str 'window { width: 300px; } listview { lines: 5; }'
fi

exit 0
