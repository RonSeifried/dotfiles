#!/usr/bin/env bash
# MCP Management – Docker MCP Gateway control via rofi
# Follows the same patterns as wifi.sh, vpn.sh, bluetooth.sh
set -euo pipefail

THEME="$HOME/.config/rofi/utility.rasi"
SCRIPT="$0"

# ── Icons (Nerd Font) ────────────────────────────────────────────────
IC_CATALOG="󰏗"
IC_SERVER="󱘖"
IC_GATEWAY="󰒋"
IC_CLIENT="󰙯"
IC_TOOLS="󰒓"
IC_FEATURE="󰘵"
IC_SECRET="󰯄"
IC_BACK="󰁍"
IC_ENABLE="󰐊"
IC_DISABLE="󰓛"
IC_INSPECT="󰙎"
IC_CONNECT="󱘖"
IC_DISCONNECT="󱘗"
IC_START="󱓞"
IC_COUNT="󰆙"
IC_SEARCH="󰍉"
IC_OK="󰄬"
IC_ERR="󰅝"
IC_WARN="󰀦"
IC_ON="󰔡"
IC_OFF="󰨙"

# ── Dependency check ─────────────────────────────────────────────────
preflight() {
    if ! command -v docker &>/dev/null; then
        notify-send "MCP Management" "docker not found – please install Docker Engine" -u critical
        exit 1
    fi
    if ! docker mcp version &>/dev/null 2>&1; then
        notify-send "MCP Management" "docker mcp not available – install the Docker MCP plugin" -u critical
        exit 1
    fi
}

# ── Helpers ──────────────────────────────────────────────────────────
rofi_menu() {
    local prompt="$1"; shift
    rofi -dmenu -i -p "$prompt" -theme "$THEME" "$@"
}

show_in_terminal() {
    local title="$1"; shift
    kitty --detach --class "mcp-management" \
        -o "font_size=13" \
        -T "$title" \
        -e bash -c "$*; echo; echo '── Press Enter to close ──'; read"
}

# ── Parse helpers ────────────────────────────────────────────────────

# Parse catalog: extract "name  description" pairs
# Catalog format:
#   ServerName
#     Description text that may span
#     multiple lines.
# Strip ANSI escape sequences (bold, color, reset etc.)
strip_ansi() {
    sed 's/\x1b\[[0-9;]*[a-zA-Z]//g'
}

parse_catalog_entries() {
    docker mcp catalog show docker-mcp 2>/dev/null | strip_ansi | awk '
        # Server name: exactly 2 leading spaces, then a non-space char
        /^  [^ ]/ && !/^  (MCP Server|[0-9]+ servers|──)/ {
            if (name != "") print name "\t" desc
            gsub(/^  /, "")
            name = $0
            desc = ""
            next
        }
        # Description: 4+ leading spaces
        /^    / && name != "" {
            gsub(/^    /, "")
            if (desc == "") desc = $0
            else desc = desc " " $0
        }
        END { if (name != "") print name "\t" desc }
    '
}

# Parse enabled servers from `docker mcp server ls`
# Format:
#   NAME            OAUTH      SECRETS    CONFIG     DESCRIPTION
#   ---------------------------------------------------------------------
#   fetch           -          -          -          Fetches a URL fro...
parse_enabled_servers() {
    docker mcp server ls 2>/dev/null \
        | strip_ansi \
        | grep -v '^Warning:' \
        | grep -v '^$' \
        | grep -v '^MCP Servers' \
        | grep -v '^NAME' \
        | grep -v '^---' \
        | grep -v '^Tip:' \
        | grep -v '^No server' \
        | awk 'NF > 0 { print $1 }'
}

# Parse tools from `docker mcp tools ls`
# Format:
#   6 tools:
#    - tool-name - Description text
parse_tools() {
    docker mcp tools ls 2>/dev/null \
        | strip_ansi \
        | grep '^ - ' \
        | sed 's/^ - //'
}

# Parse features from `docker mcp feature ls`
# Format:
#   oauth-interceptor    disabled
#                        Enable GitHub OAuth flow interception...
#   (blank line)
#   mcp-oauth-dcr        enabled
#                        Enable Dynamic Client Registration...
parse_features() {
    docker mcp feature ls 2>/dev/null | strip_ansi | awk '
        /^  [a-z]/ {
            # Line contains both name and status, e.g. "  oauth-interceptor    disabled"
            name = $1
            status = $NF
            # Next line is the description
            getline
            gsub(/^[[:space:]]+/, "")
            desc = $0
            if (status == "enabled") icon = "'"$IC_ON"'"
            else icon = "'"$IC_OFF"'"
            print icon "  " name "  –  " desc
        }
    '
}

# Parse supported clients from help text
parse_supported_clients() {
    docker mcp client connect --help 2>&1 \
        | strip_ansi \
        | grep 'Supported clients:' \
        | sed 's/.*Supported clients: //' \
        | tr ' ' '\n'
}

# Parse client status from `docker mcp client ls`
parse_client_status() {
    docker mcp client ls 2>&1 | strip_ansi | awk '
        /^ ●/ {
            gsub(/^ ● /, "")
            split($0, parts, ": ")
            name = parts[1]
            status = parts[2]
            print name "\t" status
        }
    '
}

# ── Main menu ────────────────────────────────────────────────────────
menu_main() {
    local chosen
    chosen=$(printf '%s\n' \
        "$IC_SEARCH  Browse Catalog" \
        "$IC_SERVER  Enabled Servers" \
        "$IC_CLIENT  Clients" \
        "$IC_TOOLS  Tools" \
        "$IC_GATEWAY  Gateway" \
        "$IC_FEATURE  Features" \
        "$IC_SECRET  Secrets" \
        | rofi_menu "󰡨 MCP")

    [[ -z "$chosen" ]] && exit 0

    case "$chosen" in
        *"Browse Catalog"*)    exec "$SCRIPT" catalog ;;
        *"Enabled Servers"*)   exec "$SCRIPT" servers ;;
        *"Clients"*)           exec "$SCRIPT" clients ;;
        *"Tools"*)             exec "$SCRIPT" tools ;;
        *"Gateway"*)           exec "$SCRIPT" gateway ;;
        *"Features"*)          exec "$SCRIPT" features ;;
        *"Secrets"*)           exec "$SCRIPT" secrets ;;
    esac
}

# ── Catalog: browse & enable ─────────────────────────────────────────
menu_catalog() {
    local entries chosen name

    notify-send "$IC_CATALOG MCP" "Loading catalog…" -t 1500

    # Build "name - description" lines for rofi
    entries=$(parse_catalog_entries | while IFS=$'\t' read -r n d; do
        # Truncate description for rofi display
        d="${d:0:80}"
        echo "$n  –  $d"
    done)

    if [[ -z "$entries" ]]; then
        notify-send "$IC_WARN MCP" "Catalog is empty. Run 'docker mcp catalog init' first." -u normal
        exec "$SCRIPT"
    fi

    chosen=$(echo "$entries" | rofi_menu "$IC_CATALOG Catalog (search)")
    [[ -z "$chosen" ]] && exec "$SCRIPT"

    # Extract server name (everything before "  –  ")
    name="${chosen%%  –  *}"
    name="$(echo "$name" | xargs)"

    [[ -z "$name" ]] && exec "$SCRIPT"

    # Show server action submenu
    menu_catalog_action "$name"
}

menu_catalog_action() {
    local name="$1"
    local chosen

    chosen=$(printf '%s\n' \
        "$IC_ENABLE  Enable \"$name\"" \
        "$IC_INSPECT  Inspect \"$name\"" \
        "" \
        "$IC_BACK  Back to Catalog" \
        | rofi_menu "$IC_CATALOG $name")

    [[ -z "$chosen" ]] && exec "$SCRIPT" catalog

    case "$chosen" in
        *"Enable"*)
            local output
            output=$(docker mcp server enable "$name" 2>&1) || true
            if echo "$output" | grep -qi "enabled\|success\|✓"; then
                notify-send "$IC_OK MCP" "Server '$name' enabled" -t 3000
            else
                notify-send "$IC_ERR MCP" "Enable failed: $output" -u critical
            fi
            # Stay in catalog for enabling more
            exec "$SCRIPT" catalog
            ;;
        *"Inspect"*)
            show_in_terminal "MCP – $name" "docker mcp server inspect '$name' 2>&1 | less -R"
            ;;
        *"Back"*)
            exec "$SCRIPT" catalog
            ;;
    esac
}

# ── Enabled servers: manage ──────────────────────────────────────────
menu_servers() {
    local servers chosen

    servers=$(parse_enabled_servers)

    if [[ -z "$servers" ]]; then
        local action
        action=$(printf '%s\n' \
            "$IC_SEARCH  Browse Catalog to enable servers" \
            "$IC_BACK  Back" \
            | rofi_menu "$IC_SERVER No servers enabled")
        case "$action" in
            *"Browse"*) exec "$SCRIPT" catalog ;;
            *)          exec "$SCRIPT" ;;
        esac
    fi

    chosen=$(echo "$servers" | rofi_menu "$IC_SERVER Enabled Servers")
    [[ -z "$chosen" ]] && exec "$SCRIPT"

    menu_server_action "$chosen"
}

menu_server_action() {
    local name="$1"
    local chosen

    chosen=$(printf '%s\n' \
        "$IC_INSPECT  Inspect" \
        "$IC_DISABLE  Disable" \
        "$IC_TOOLS  Show Tools" \
        "" \
        "$IC_BACK  Back to Servers" \
        | rofi_menu "$IC_SERVER $name")

    [[ -z "$chosen" ]] && exec "$SCRIPT" servers

    case "$chosen" in
        *"Inspect"*)
            show_in_terminal "MCP – $name" "docker mcp server inspect '$name' 2>&1 | less -R"
            ;;
        *"Disable"*)
            local output
            output=$(docker mcp server disable "$name" 2>&1) || true
            if echo "$output" | grep -qi "disabled\|success\|✓"; then
                notify-send "$IC_OK MCP" "Server '$name' disabled" -t 3000
            else
                notify-send "$IC_ERR MCP" "Disable failed: $output" -u critical
            fi
            exec "$SCRIPT" servers
            ;;
        *"Show Tools"*)
            show_in_terminal "MCP – Tools ($name)" "docker mcp tools ls 2>&1 | less -R"
            ;;
        *"Back"*)
            exec "$SCRIPT" servers
            ;;
    esac
}

# ── Clients: connect/disconnect editors ──────────────────────────────
menu_clients() {
    local status_lines chosen

    # Build client list with status
    status_lines=$(parse_client_status | while IFS=$'\t' read -r cname cstatus; do
        if echo "$cstatus" | grep -qi "connected\b" && ! echo "$cstatus" | grep -qi "disconnected"; then
            echo "$IC_ON  $cname  ($cstatus)"
        else
            echo "$IC_OFF  $cname  ($cstatus)"
        fi
    done)

    if [[ -z "$status_lines" ]]; then
        # Fallback: show supported clients
        status_lines=$(parse_supported_clients | while read -r c; do
            echo "$IC_OFF  $c"
        done)
    fi

    chosen=$(printf '%s\n%s\n%s' \
        "$status_lines" \
        "" \
        "$IC_BACK  Back" \
        | rofi_menu "$IC_CLIENT Clients")

    [[ -z "$chosen" ]] && exec "$SCRIPT"

    case "$chosen" in
        *"Back"*)
            exec "$SCRIPT"
            ;;
        "$IC_ON  "*)
            # Connected → offer disconnect
            local cname
            cname=$(echo "$chosen" | sed "s/^$IC_ON  //; s/  (.*//")
            menu_client_action "$cname" "connected"
            ;;
        "$IC_OFF  "*)
            # Disconnected → offer connect
            local cname
            cname=$(echo "$chosen" | sed "s/^$IC_OFF  //; s/  (.*//")
            menu_client_action "$cname" "disconnected"
            ;;
    esac
}

menu_client_action() {
    local cname="$1" state="$2"
    local chosen

    if [[ "$state" == "connected" ]]; then
        chosen=$(printf '%s\n%s\n%s' \
            "$IC_DISCONNECT  Disconnect $cname" \
            "" \
            "$IC_BACK  Back" \
            | rofi_menu "$IC_CLIENT $cname")
    else
        chosen=$(printf '%s\n%s\n%s\n%s' \
            "$IC_CONNECT  Connect $cname" \
            "$IC_CONNECT  Connect $cname (global)" \
            "" \
            "$IC_BACK  Back" \
            | rofi_menu "$IC_CLIENT $cname")
    fi

    [[ -z "$chosen" ]] && exec "$SCRIPT" clients

    case "$chosen" in
        *"Disconnect"*)
            local output
            output=$(docker mcp client disconnect "$cname" 2>&1) || true
            notify-send "$IC_OK MCP" "Client '$cname' disconnected" -t 3000
            exec "$SCRIPT" clients
            ;;
        *"global"*)
            local output
            output=$(docker mcp client connect "$cname" --global 2>&1) || true
            notify-send "$IC_OK MCP" "Client '$cname' connected (global)" -t 3000
            exec "$SCRIPT" clients
            ;;
        *"Connect"*)
            local output
            output=$(docker mcp client connect "$cname" 2>&1) || true
            notify-send "$IC_OK MCP" "Client '$cname' connected" -t 3000
            exec "$SCRIPT" clients
            ;;
        *"Back"*)
            exec "$SCRIPT" clients
            ;;
    esac
}

# ── Tools: list, inspect, enable/disable ─────────────────────────────
menu_tools() {
    local tools_raw chosen

    tools_raw=$(parse_tools)

    if [[ -z "$tools_raw" ]]; then
        local action
        action=$(printf '%s\n%s' \
            "$IC_COUNT  No tools loaded (enable servers first)" \
            "$IC_BACK  Back" \
            | rofi_menu "$IC_TOOLS Tools")
        case "$action" in
            *"Back"*) exec "$SCRIPT" ;;
            *) exec "$SCRIPT" ;;
        esac
    fi

    # Format: "tool-name - Description"
    # Show with count in prompt
    local count
    count=$(echo "$tools_raw" | wc -l)

    chosen=$(echo "$tools_raw" | rofi_menu "$IC_TOOLS Tools ($count)")
    [[ -z "$chosen" ]] && exec "$SCRIPT"

    # Extract tool name (first word before " - ")
    local tname
    tname="${chosen%% - *}"
    tname="$(echo "$tname" | xargs)"

    [[ -z "$tname" ]] && exec "$SCRIPT" tools

    menu_tool_action "$tname"
}

menu_tool_action() {
    local tname="$1"
    local chosen

    chosen=$(printf '%s\n%s\n%s\n%s\n%s' \
        "$IC_INSPECT  Inspect" \
        "$IC_DISABLE  Disable" \
        "$IC_ENABLE  Enable" \
        "" \
        "$IC_BACK  Back to Tools" \
        | rofi_menu "$IC_TOOLS $tname")

    [[ -z "$chosen" ]] && exec "$SCRIPT" tools

    case "$chosen" in
        *"Inspect"*)
            show_in_terminal "Tool – $tname" "docker mcp tools inspect '$tname' 2>&1 | less -R"
            ;;
        *"Disable"*)
            local output
            output=$(docker mcp tools disable "$tname" 2>&1) || true
            notify-send "$IC_OK MCP" "Tool '$tname' disabled" -t 3000
            exec "$SCRIPT" tools
            ;;
        *"Enable"*)
            local output
            output=$(docker mcp tools enable "$tname" 2>&1) || true
            notify-send "$IC_OK MCP" "Tool '$tname' enabled" -t 3000
            exec "$SCRIPT" tools
            ;;
        *"Back"*)
            exec "$SCRIPT" tools
            ;;
    esac
}

# ── Gateway ──────────────────────────────────────────────────────────
menu_gateway() {
    local chosen

    chosen=$(printf '%s\n%s\n%s\n%s\n%s' \
        "$IC_START  Start Gateway" \
        "$IC_COUNT  Tool Count" \
        "$IC_TOOLS  List Tools" \
        "" \
        "$IC_BACK  Back" \
        | rofi_menu "$IC_GATEWAY Gateway")

    [[ -z "$chosen" ]] && exec "$SCRIPT"

    case "$chosen" in
        *"Start Gateway"*)
            notify-send "$IC_GATEWAY MCP" "Starting MCP Gateway…" -t 2000
            kitty --detach --class "mcp-gateway" \
                -o "font_size=13" \
                -T "MCP Gateway" \
                -e bash -c "docker mcp gateway run; echo; echo '── Gateway stopped. Press Enter ──'; read"
            ;;
        *"Tool Count"*)
            local count
            count=$(docker mcp tools count 2>&1) || count="Error"
            notify-send "$IC_COUNT MCP" "$count" -t 5000
            ;;
        *"List Tools"*)
            show_in_terminal "MCP – All Tools" "docker mcp tools ls 2>&1 | less -R"
            ;;
        *"Back"*)
            exec "$SCRIPT"
            ;;
    esac
}

# ── Features: toggle experimental flags ──────────────────────────────
menu_features() {
    local features chosen

    features=$(parse_features)

    if [[ -z "$features" ]]; then
        notify-send "$IC_WARN MCP" "Could not load feature flags" -u normal
        exec "$SCRIPT"
    fi

    chosen=$(printf '%s\n%s\n%s' \
        "$features" \
        "" \
        "$IC_BACK  Back" \
        | rofi_menu "$IC_FEATURE Features")

    [[ -z "$chosen" ]] && exec "$SCRIPT"

    case "$chosen" in
        *"Back"*)
            exec "$SCRIPT"
            ;;
        *)
            # Format: "ICON  name  –  description"
            # Extract feature name (second field) and determine state from icon
            local fname is_enabled
            fname=$(echo "$chosen" | awk '{print $2}')
            # Check if the line starts with the "enabled" icon
            is_enabled=false
            echo "$chosen" | grep -q "^$IC_ON" && is_enabled=true

            if [[ "$is_enabled" == true ]]; then
                # Currently enabled → disable
                local confirm
                confirm=$(printf '%s\n%s' \
                    "$IC_DISABLE  Disable $fname" \
                    "$IC_BACK  Cancel" \
                    | rofi_menu "$IC_FEATURE $fname")
                if echo "$confirm" | grep -qi "Disable"; then
                    docker mcp feature disable "$fname" 2>&1 || true
                    notify-send "$IC_OK MCP" "Feature '$fname' disabled" -t 3000
                fi
            else
                # Currently disabled → enable
                local confirm
                confirm=$(printf '%s\n%s' \
                    "$IC_ENABLE  Enable $fname" \
                    "$IC_BACK  Cancel" \
                    | rofi_menu "$IC_FEATURE $fname")
                if echo "$confirm" | grep -qi "Enable"; then
                    docker mcp feature enable "$fname" 2>&1 || true
                    notify-send "$IC_OK MCP" "Feature '$fname' enabled" -t 3000
                fi
            fi
            exec "$SCRIPT" features
            ;;
    esac
}

# ── Secrets ──────────────────────────────────────────────────────────
menu_secrets() {
    local chosen

    chosen=$(printf '%s\n%s\n%s\n%s\n%s' \
        "$IC_SEARCH  List Secrets" \
        "$IC_ENABLE  Set Secret" \
        "$IC_DISABLE  Remove Secret" \
        "" \
        "$IC_BACK  Back" \
        | rofi_menu "$IC_SECRET Secrets")

    [[ -z "$chosen" ]] && exec "$SCRIPT"

    case "$chosen" in
        *"List"*)
            show_in_terminal "MCP – Secrets" "docker mcp secret ls 2>&1; echo; docker mcp policy dump 2>&1"
            ;;
        *"Set Secret"*)
            local input
            input=$(echo "" | rofi_menu "$IC_SECRET Set (KEY=VALUE)" \
                -theme-str 'listview { lines: 0; } entry { placeholder: "SECRET_NAME=value"; }')
            [[ -z "$input" ]] && exec "$SCRIPT" secrets
            local output
            output=$(docker mcp secret set "$input" 2>&1) || true
            notify-send "$IC_SECRET MCP" "$output" -t 4000
            exec "$SCRIPT" secrets
            ;;
        *"Remove"*)
            # List existing secrets and let user pick
            local slist sname
            slist=$(docker mcp secret ls 2>&1 | grep -v '^$' | grep -v 'error' || echo "")
            if [[ -z "$slist" ]]; then
                notify-send "$IC_WARN MCP" "No secrets found or secret store unavailable" -u normal
                exec "$SCRIPT" secrets
            fi
            sname=$(echo "$slist" | rofi_menu "$IC_SECRET Remove Secret")
            [[ -z "$sname" ]] && exec "$SCRIPT" secrets
            docker mcp secret rm "$sname" 2>&1 || true
            notify-send "$IC_OK MCP" "Secret '$sname' removed" -t 3000
            exec "$SCRIPT" secrets
            ;;
        *"Back"*)
            exec "$SCRIPT"
            ;;
    esac
}

# ── Entry point ──────────────────────────────────────────────────────
preflight

case "${1:-}" in
    catalog)   menu_catalog   ;;
    servers)   menu_servers   ;;
    clients)   menu_clients   ;;
    tools)     menu_tools     ;;
    gateway)   menu_gateway   ;;
    features)  menu_features  ;;
    secrets)   menu_secrets   ;;
    *)         menu_main      ;;
esac

exit 0
