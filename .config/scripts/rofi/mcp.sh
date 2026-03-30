#!/usr/bin/env bash
set -euo pipefail

THEME="${THEME:-$HOME/.config/rofi/utility.rasi}"
MCPY_BIN="${MCPY_BIN:-$HOME/dev/personal/mcpy/.venv/bin/mcpy}"


IC_MAIN="󰡨"
IC_SERVER="󱘖"
IC_CLIENT="󰙯"
IC_TOOLS="󰒓"
IC_FEATURE="󰘵"
IC_CATALOG="󰏗"
IC_GATEWAY="󰒋"
IC_SETTINGS="󰍡"
IC_SEARCH="󰍉"
IC_ENABLE="󰐊"
IC_DISABLE="󰓛"
IC_INSPECT="󰙎"
IC_BACK="󰁍"
IC_OK="󰄬"
IC_ERR="󰅝"

preflight() {
    if ! command -v rofi >/dev/null 2>&1; then
        notify-send "MCP" "rofi not found" -u critical
        exit 1
    fi

    if ! command -v "$MCPY_BIN" >/dev/null 2>&1; then
        notify-send "MCP" "mcpy not found on PATH" -u critical
        exit 1
    fi
}

rofi_menu() {
    local prompt="$1"
    shift
    if [[ $# -gt 0 ]]; then
        printf '%s\n' "$@" | rofi -dmenu -i -p "$prompt" -theme "$THEME"
    else
        rofi -dmenu -i -p "$prompt" -theme "$THEME"
    fi
}

notify_ok() {
    notify-send "MCP" "$1" -t 2500
}

notify_err() {
    notify-send "MCP" "$1" -u critical
}

run_mcpy() {
    "$MCPY_BIN" "$@"
}

show_in_terminal() {
    local title="$1"
    shift
    kitty --detach --class "mcp-management" \
        -o "font_size=13" \
        -T "$title" \
        -e bash -lc "$*"
}

pick_first_token() {
    awk '{print $1}'
}

exec_back() {
    local target="${1:-}"
    if [[ -n "$target" ]]; then
        exec "$0" "$target"
    fi
    exec "$0"
}

choose_name() {
    pick_first_token | xargs
}

choose_action() {
    rofi_menu "$1" "$2" "$3" "$4"
}

menu_main() {
    local chosen
    chosen=$(printf '%s\n' \
        "$IC_CATALOG  Browse Catalog" \
        "$IC_SERVER  Enabled Servers" \
        "$IC_CLIENT  Clients" \
        "$IC_TOOLS  Tools" \
        "$IC_GATEWAY  Gateway" \
        "$IC_FEATURE  Features" \
        "$IC_SETTINGS  Settings" \
        | rofi_menu "$IC_MAIN MCP")

    [[ -z "$chosen" ]] && exit 0

    case "$chosen" in
        *"Browse Catalog"*) exec_back catalog ;;
        *"Enabled Servers"*) exec_back servers ;;
        *"Clients"*) exec_back clients ;;
        *"Tools"*) exec_back tools ;;
        *"Gateway"*) exec_back gateway ;;
        *"Features"*) exec_back features ;;
        *"Settings"*) exec_back settings ;;
    esac
}

menu_catalog() {
    local chosen name action
    chosen=$(run_mcpy catalog rofi | rofi_menu "$IC_CATALOG Catalog")
    [[ -z "$chosen" ]] && exec_back

    name=$(printf '%s\n' "$chosen" | choose_name)
    [[ -z "$name" ]] && exec_back catalog

    action=$(printf '%s\n' \
        "$IC_ENABLE  Enable $name" \
        "$IC_INSPECT  Inspect $name" \
        "$IC_BACK  Back" \
        | rofi_menu "$IC_CATALOG $name")

    case "$action" in
        *"Enable"*)
            if run_mcpy servers enable "$name" >/dev/null 2>&1; then
                notify_ok "$name enabled"
            else
                notify_err "Failed to enable $name"
            fi
            exec_back catalog
            ;;
        *"Inspect"*)
            show_in_terminal "MCP – $name" "$MCPY_BIN servers inspect '$name' 2>&1 | less -R"
            ;;
        *)
            exec_back catalog
            ;;
    esac
}

menu_servers() {
    local chosen name action
    chosen=$(run_mcpy servers rofi | rofi_menu "$IC_SERVER Enabled Servers")
    [[ -z "$chosen" ]] && exec_back

    name=$(printf '%s\n' "$chosen" | choose_name)
    [[ -z "$name" ]] && exec_back servers

    action=$(printf '%s\n' \
        "$IC_INSPECT  Inspect $name" \
        "$IC_DISABLE  Disable $name" \
        "$IC_BACK  Back" \
        | rofi_menu "$IC_SERVER $name")

    case "$action" in
        *"Inspect"*)
            show_in_terminal "MCP – $name" "$MCPY_BIN servers inspect '$name' 2>&1 | less -R"
            ;;
        *"Disable"*)
            if run_mcpy servers disable "$name" >/dev/null 2>&1; then
                notify_ok "$name disabled"
            else
                notify_err "Failed to disable $name"
            fi
            exec_back servers
            ;;
        *)
            exec_back servers
            ;;
    esac
}

menu_clients() {
    local chosen name action
    chosen=$(run_mcpy clients rofi | rofi_menu "$IC_CLIENT Clients")
    [[ -z "$chosen" ]] && exec_back

    name=$(printf '%s\n' "$chosen" | choose_name)
    [[ -z "$name" ]] && exec_back clients

    action=$(printf '%s\n' \
        "$IC_ENABLE  Connect $name" \
        "$IC_DISABLE  Disconnect $name" \
        "$IC_BACK  Back" \
        | rofi_menu "$IC_CLIENT $name")

    case "$action" in
        *"Connect"*)
            if run_mcpy clients connect "$name" >/dev/null 2>&1; then
                notify_ok "$name connected"
            else
                notify_err "Failed to connect $name"
            fi
            exec_back clients
            ;;
        *"Disconnect"*)
            if run_mcpy clients disconnect "$name" >/dev/null 2>&1; then
                notify_ok "$name disconnected"
            else
                notify_err "Failed to disconnect $name"
            fi
            exec_back clients
            ;;
        *)
            exec_back clients
            ;;
    esac
}

menu_tools() {
    local chosen name action
    chosen=$(run_mcpy tools rofi | rofi_menu "$IC_TOOLS Tools")
    [[ -z "$chosen" ]] && exec_back

    name=$(printf '%s\n' "$chosen" | choose_name)
    [[ -z "$name" ]] && exec_back tools

    action=$(printf '%s\n' \
        "$IC_INSPECT  Inspect $name" \
        "$IC_BACK  Back" \
        | rofi_menu "$IC_TOOLS $name")

    case "$action" in
        *"Inspect"*)
            show_in_terminal "MCP – Tool: $name" "$MCPY_BIN tools inspect '$name' 2>&1 | less -R"
            ;;
        *)
            exec_back tools
            ;;
    esac
}

menu_gateway() {
    local chosen
    chosen=$(printf '%s\n' \
        "$IC_INSPECT  Gateway Status" \
        "$IC_ENABLE  Start Gateway" \
        "$IC_BACK  Back" \
        | rofi_menu "$IC_GATEWAY Gateway")

    case "$chosen" in
        *"Gateway Status"*)
            show_in_terminal "MCP Gateway" "$MCPY_BIN gateway status 2>&1 | less -R"
            ;;
        *"Start Gateway"*)
            show_in_terminal "MCP Gateway" "$MCPY_BIN gateway run"
            ;;
        *)
            exec_back
            ;;
    esac
}

menu_features() {
    local chosen name action
    chosen=$(run_mcpy features rofi | rofi_menu "$IC_FEATURE Features")
    [[ -z "$chosen" ]] && exec_back

    name=$(printf '%s\n' "$chosen" | choose_name)
    [[ -z "$name" ]] && exec_back features

    action=$(printf '%s\n' \
        "$IC_ENABLE  Enable $name" \
        "$IC_DISABLE  Disable $name" \
        "$IC_BACK  Back" \
        | rofi_menu "$IC_FEATURE $name")

    case "$action" in
        *"Enable"*)
            if run_mcpy features enable "$name" >/dev/null 2>&1; then
                notify_ok "$name enabled"
            else
                notify_err "Failed to enable $name"
            fi
            exec_back features
            ;;
        *"Disable"*)
            if run_mcpy features disable "$name" >/dev/null 2>&1; then
                notify_ok "$name disabled"
            else
                notify_err "Failed to disable $name"
            fi
            exec_back features
            ;;
        *)
            exec_back features
            ;;
    esac
}

menu_settings() {
    local action key value
    action=$(printf '%s\n' \
        "$IC_SEARCH  Show Config" \
        "$IC_ENABLE  Set Value" \
        "$IC_INSPECT  Edit Config" \
        "$IC_BACK  Back" \
        | rofi_menu "$IC_SETTINGS Settings")

    case "$action" in
        *"Show Config"*)
            show_in_terminal "mcpy config" "$MCPY_BIN settings list 2>&1 | less -R"
            ;;
        *"Set Value"*)
            key=$(rofi -dmenu -i -p "Key" -theme "$THEME")
            [[ -z "$key" ]] && exec_back settings
            value=$(rofi -dmenu -i -p "Value" -theme "$THEME")
            [[ -z "$value" ]] && exec_back settings
            if run_mcpy settings set "$key" "$value" >/dev/null 2>&1; then
                notify_ok "$key updated"
            else
                notify_err "Failed to set $key"
            fi
            exec_back settings
            ;;
        *"Edit Config"*)
            run_mcpy settings edit >/dev/null 2>&1
            exec_back settings
            ;;
        *)
            exec_back
            ;;
    esac
}

preflight

case "${1:-}" in
    catalog) menu_catalog ;;
    servers) menu_servers ;;
    clients) menu_clients ;;
    tools) menu_tools ;;
    gateway) menu_gateway ;;
    features) menu_features ;;
    settings) menu_settings ;;
    *) menu_main ;;
esac
