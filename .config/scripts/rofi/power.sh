#!/usr/bin/env bash
# Power Menu – THE single power menu for the entire system
# Called from: Waybar power button, Super+Shift+L, swaync
# Theme: compact power.rasi (no wallpaper image)

ICON_LOCK="󰌾"
ICON_LOGOUT="󰍃"
ICON_SUSPEND="󰤄"
ICON_REBOOT="󰜉"
ICON_SHUTDOWN="󰐥"
ICON_CANCEL="󰜺"

THEME="$HOME/.config/rofi/power.rasi"

execute_action() {
    case "$1" in
        lock)
            hyprlock 2>/dev/null || swaylock -f 2>/dev/null || loginctl lock-session
            ;;
        logout)    hyprctl dispatch exit 2>/dev/null || loginctl terminate-user "$USER" ;;
        suspend)   systemctl suspend ;;
        reboot)    systemctl reboot ;;
        shutdown)  systemctl poweroff ;;
    esac
}

CONFIRM_THEME="$HOME/.config/rofi/confirm.rasi"

confirm() {
    local action="$1" label="$2"
    local answer
    answer=$(printf "%s\n%s" "󰜺  Cancel" "󰄬  Yes" \
        | rofi -dmenu -i -p "$label" -mesg "Are you sure?" -theme "$CONFIRM_THEME")
    [[ "$answer" == *"Yes"* ]] && execute_action "$action"
}

# Build main menu
chosen=$(printf "%s\n%s\n%s\n%s\n%s" \
    "$ICON_LOCK  Lock" \
    "$ICON_LOGOUT  Logout" \
    "$ICON_SUSPEND  Suspend" \
    "$ICON_REBOOT  Reboot" \
    "$ICON_SHUTDOWN  Shutdown" \
    | rofi -dmenu -i -p "Power" -theme "$THEME")

[[ -z "$chosen" ]] && exit 0

case "$chosen" in
    *Lock)     execute_action lock ;;
    *Suspend)  execute_action suspend ;;
    *Logout)   confirm logout "Logout" ;;
    *Reboot)   confirm reboot "Reboot" ;;
    *Shutdown) confirm shutdown "Shutdown" ;;
esac

exit 0
