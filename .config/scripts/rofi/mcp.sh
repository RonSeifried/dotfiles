#!/usr/bin/env bash
set -euo pipefail

THEME="${THEME:-$HOME/.config/rofi/utility.rasi}"
INFO_PY="${INFO_PY:-$HOME/.config/scripts/rofi/mcp-server-info.py}"
SECRETS_ENV="${SECRETS_ENV:-$HOME/.docker/mcp/secrets.env}"
CATALOG_FILE="${CATALOG_FILE:-$HOME/.docker/mcp/catalogs/docker-mcp.yaml}"
CLAUDE_JSON="${CLAUDE_JSON:-$HOME/.claude.json}"

IC_MAIN="󰡨"
IC_SERVER="󱘖"
IC_CLIENT="󰙯"
IC_TOOLS="󰒓"
IC_CATALOG="󰏗"
IC_GATEWAY="󰒋"
IC_SECRET="󰌆"
IC_BACK="󰁍"
IC_ENABLE="󰐊"
IC_DISABLE="󰓛"
IC_INSPECT="󰙎"
IC_INFO="󰋼"
IC_EDIT="󰏫"
IC_DEL="󰆴"
IC_WARN="󰀦"

SUPPORTED_CLIENTS="claude-code claude-desktop cline codex continue crush cursor gemini goose gordon kiro lmstudio opencode sema4 vscode zed"

# ── preflight ─────────────────────────────────────────────────
preflight() {
    if ! command -v rofi >/dev/null 2>&1; then
        notify-send "MCP" "rofi not found" -u critical; exit 1
    fi
    if ! command -v docker >/dev/null 2>&1; then
        notify-send "MCP" "docker not found" -u critical; exit 1
    fi
    if ! docker mcp --help >/dev/null 2>&1; then
        notify-send "MCP" "docker mcp plugin not available" -u critical; exit 1
    fi
    # Ensure secrets file exists with safe permissions
    if [[ ! -f "$SECRETS_ENV" ]]; then
        mkdir -p "$(dirname "$SECRETS_ENV")"
        touch "$SECRETS_ENV"
        chmod 600 "$SECRETS_ENV"
    fi
    # Ensure gateway config uses secrets.env so clients receive secrets
    _ensure_gateway_config
}

# Patch ~/.claude.json MCP_DOCKER command to include --secrets flag.
# Idempotent: safe to run every startup; re-patches after docker mcp client connect overwrites it.
_ensure_gateway_config() {
    [[ -f "$CLAUDE_JSON" ]] || return 0
    python3 - "$CLAUDE_JSON" "$SECRETS_ENV" << 'PYEOF'
import json, sys

path, secrets_env = sys.argv[1], sys.argv[2]
with open(path) as f:
    d = json.load(f)

mcp_docker = d.get('mcpServers', {}).get('MCP_DOCKER', {})
if not mcp_docker:
    sys.exit(0)  # not connected yet

args = mcp_docker.get('args', [])
if '--secrets' not in args:
    args.extend(['--secrets', secrets_env])
    mcp_docker['args'] = args
    d['mcpServers']['MCP_DOCKER'] = mcp_docker
    with open(path, 'w') as f:
        json.dump(d, f, indent=2)
PYEOF
}

# ── helpers ───────────────────────────────────────────────────
rofi_menu() {
    local prompt="$1"; shift
    if [[ $# -gt 0 ]]; then
        printf '%s\n' "$@" | rofi -dmenu -i -p "$prompt" -theme "$THEME"
    else
        rofi -dmenu -i -p "$prompt" -theme "$THEME"
    fi
}

notify_ok()  { notify-send "MCP" "$1" -t 2500; }
notify_err() { notify-send "MCP" "$1" -u critical; }

show_in_terminal() {
    local title="$1"; shift
    kitty --detach --class "mcp-management" \
        -o "font_size=13" -T "$title" \
        -e bash -lc "$*; echo; printf '── press any key to close ──'; read -rn1"
}

exec_back() {
    [[ -n "${1:-}" ]] && exec "$0" "$1"
    exec "$0"
}

# ── secret input via kitty terminal (blocking) ────────────────
# Opens a kitty window, reads secret value hidden, writes to tempfile.
# Prints the value to stdout. Returns empty string if cancelled.
secret_input_terminal() {
    local secret_name="$1"
    local tmpfile helper
    tmpfile=$(mktemp /tmp/mcp-val-XXXXXX)
    helper=$(mktemp /tmp/mcp-helper-XXXXXX.sh)
    chmod 600 "$tmpfile"
    chmod 700 "$helper"

    # Write helper script (heredoc expands secret_name + tmpfile at write time)
    cat > "$helper" << HELPER
#!/usr/bin/env bash
printf '\033[1;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n'
printf '  \033[1mMCP Secret\033[0m\n'
printf '\033[1;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n\n'
printf '  Key:  \033[1;33m${secret_name}\033[0m\n\n'
printf '  Paste value (input hidden, Enter to confirm):\n  > '
IFS= read -rsp '' val
printf '\n'
if [[ -n "\$val" ]]; then
    printf '%s' "\$val" > '${tmpfile}'
    printf '\n  \033[1;32m✓ Saved\033[0m — closing...\n'
else
    printf '\n  \033[1;31m✗ Empty — cancelled.\033[0m\n'
fi
sleep 0.8
HELPER

    # kitty without --detach blocks until window closes
    kitty --class "mcp-management" -o "font_size=13" \
        -T "MCP Secret — ${secret_name}" \
        -e bash "$helper" 2>/dev/null || true

    rm -f "$helper"
    local value
    value=$(cat "$tmpfile" 2>/dev/null || true)
    rm -f "$tmpfile"
    printf '%s' "$value"
}

# ── data helpers ──────────────────────────────────────────────

# Parse catalog: strip ANSI, grab "  ServerName" lines
catalog_names() {
    docker mcp catalog show 2>/dev/null \
        | sed 's/\x1b\[[0-9;]*m//g' \
        | grep -E "^  [A-Za-z]" \
        | grep -v "MCP Server Directory" \
        | awk '{print $1}'
}

# Parse server ls: actual name lines (lowercase start, skip headers/warnings)
server_names() {
    docker mcp server ls 2>/dev/null | awk '/^[a-z_]/{print $1}'
}

# Parse tools ls: "- toolname - desc" lines
tool_names() {
    docker mcp tools ls 2>/dev/null | grep "^ -" | awk '{print $2}'
}

# ── catalog-based secret definitions ─────────────────────────
# Parses ~/.docker/mcp/catalogs/docker-mcp.yaml for a server's secrets.
# Prints: catalog_name|ENV_VAR_NAME  (one per line)
# catalog_name is the key used in secrets.env (e.g. github.personal_access_token)
# ENV_VAR_NAME is the env var injected into the container (e.g. GITHUB_PERSONAL_ACCESS_TOKEN)
catalog_server_secrets() {
    local server="$1"
    [[ -f "$CATALOG_FILE" ]] || return 0
    python3 - "$server" "$CATALOG_FILE" << 'PYEOF'
import sys, re

server = sys.argv[1]
catalog_file = sys.argv[2]

with open(catalog_file) as f:
    lines = f.readlines()

in_server = False
server_indent = None
in_secrets = False
secrets_indent = None
i = 0

while i < len(lines):
    line = lines[i]
    raw = line.rstrip('\n')
    stripped = raw.lstrip()
    indent = len(raw) - len(stripped)

    if not in_server:
        if re.match(r'\s+' + re.escape(server) + r':\s*$', raw):
            in_server = True
            server_indent = indent
    else:
        if stripped == '' or stripped.startswith('#'):
            i += 1
            continue
        if indent <= server_indent and stripped:
            break
        if re.match(r'secrets:\s*$', stripped) and not in_secrets:
            in_secrets = True
            secrets_indent = indent
            i += 1
            continue
        if in_secrets:
            if indent <= secrets_indent and stripped and not stripped.startswith('-'):
                in_secrets = False
            elif stripped.startswith('- name:'):
                cname = stripped[len('- name:'):].strip()
                env_val = ''
                j = i + 1
                while j < len(lines):
                    nxt_raw = lines[j].rstrip('\n')
                    nxt = nxt_raw.lstrip()
                    nxt_indent = len(nxt_raw) - len(nxt)
                    if nxt_indent <= indent and nxt and not nxt.startswith('-'):
                        break
                    if re.match(r'env:\s*\S', nxt):
                        env_val = nxt[nxt.index(':')+1:].strip()
                        break
                    j += 1
                if cname:
                    fallback = cname.upper().replace('.', '_')
                    print(f"{cname}|{env_val or fallback}")
    i += 1
PYEOF
}

# Get catalog secrets for a server; fall back to README extraction if not in catalog
server_secrets_required() {
    local name="$1"
    local catalog_defs
    catalog_defs=$(catalog_server_secrets "$name") || catalog_defs=""
    if [[ -n "$catalog_defs" ]]; then
        # Return catalog_names only (first field)
        printf '%s\n' "$catalog_defs" | cut -d'|' -f1
    else
        # Fallback: README-based extraction (env var names)
        _inspect "$name" | python3 "$INFO_PY" "$name" secrets
    fi
}

# ── secrets.env file helpers ──────────────────────────────────
# Format: catalog_name=value  (e.g. github.personal_access_token=token)
# Gateway reads this via config.yaml secrets.paths — clients get env vars injected.

# Check if a catalog_name key is set (returns 0 if set)
server_secret_get() {
    local key="$2"
    [[ -f "$SECRETS_ENV" ]] && grep -qE "^${key}=" "$SECRETS_ENV" 2>/dev/null
}

# Set/update a secret in secrets.env
server_secret_set() {
    local key="$2" value="$3"
    if [[ -f "$SECRETS_ENV" ]]; then
        local tmp
        tmp=$(mktemp)
        grep -v "^${key}=" "$SECRETS_ENV" > "$tmp" || true
        mv "$tmp" "$SECRETS_ENV"
        chmod 600 "$SECRETS_ENV"
    fi
    printf '%s=%s\n' "$key" "$value" >> "$SECRETS_ENV"
    chmod 600 "$SECRETS_ENV"
}

# Remove a secret from secrets.env
server_secret_rm() {
    local key="$2"
    [[ -f "$SECRETS_ENV" ]] || return 0
    local tmp
    tmp=$(mktemp)
    grep -v "^${key}=" "$SECRETS_ENV" > "$tmp" || true
    mv "$tmp" "$SECRETS_ENV"
    chmod 600 "$SECRETS_ENV"
}

# ── server info – nested rofi navigation ─────────────────────
_INSPECT_CACHE_NAME=""
_INSPECT_CACHE_DATA=""

_inspect() {
    local name="$1"
    if [[ "$_INSPECT_CACHE_NAME" != "$name" ]]; then
        _INSPECT_CACHE_DATA=$(docker mcp server inspect "$name" 2>/dev/null)
        _INSPECT_CACHE_NAME="$name"
    fi
    printf '%s' "$_INSPECT_CACHE_DATA"
}

_rofi_info() {
    local prompt="$1"; shift
    rofi -dmenu \
         -p "$prompt" \
         -theme "$THEME" \
         -theme-str '
             window   { width: 660px; height: 500px; }
             listview { lines: 22; scrollbar: true; spacing: 0px; }
             element  { padding: 1px 10px; border-radius: 4px; }
             * { font: "JetBrainsMono Nerd Font 11"; }
         ' \
         -no-custom -i "$@"
}

show_server_tools() {
    local name="$1"
    local chosen toolname
    while true; do
        chosen=$(_inspect "$name" \
            | python3 "$INFO_PY" "$name" tools \
            | _rofi_info "$IC_TOOLS  $name — Tools") || return 0

        toolname=$(printf '%s' "$chosen" | sed 's/^[[:space:]]*[✓○][[:space:]]*//' | awk -F'  —  ' '{print $1}' | xargs)
        [[ -z "$toolname" ]] && return 0

        _inspect "$name" \
            | python3 "$INFO_PY" "$name" tool "$toolname" \
            | _rofi_info "$IC_INSPECT  $toolname" || true
    done
}

show_server_info() {
    local name="$1"
    local tool_count secret_count overview chosen
    while true; do
        overview=$(_inspect "$name" | python3 "$INFO_PY" "$name" overview)

        tool_count=$(printf '%s' "$overview" | grep -oE '[0-9]+ / [0-9]+ tools' | grep -oE '^[0-9]+' || echo "?")
        secret_count=$(printf '%s' "$overview" | grep -oE '[0-9]+ secret' | grep -oE '[0-9]+' || echo "0")

        chosen=$(printf '%s\n' \
            "$overview" \
            "" \
            "$IC_TOOLS  Tools  ($tool_count enabled)" \
            "$IC_SECRET  Secrets  ($secret_count required)" \
            | _rofi_info "$IC_INFO  $name") || return 0

        case "$chosen" in
            *Tools*)   show_server_tools "$name" ;;
            *Secrets*) exec "$0" servers_secrets "$name" ;;
        esac
    done
}

# ── secret management for a specific server ───────────────────
menu_server_secrets() {
    local server_name="${1:-}"
    [[ -z "$server_name" ]] && exec_back servers

    # Get catalog definitions: catalog_name|ENV_VAR pairs
    local secrets_defs
    secrets_defs=$(catalog_server_secrets "$server_name") || secrets_defs=""

    # Fall back to README extraction (returns env var names only)
    local using_fallback=false
    if [[ -z "$secrets_defs" ]]; then
        local fallback
        fallback=$(_inspect "$server_name" | python3 "$INFO_PY" "$server_name" secrets) || fallback=""
        if [[ -z "$fallback" ]]; then
            notify_ok "$server_name: no secrets required"
            exec_back servers
        fi
        # Wrap fallback as catalog_name|ENV_NAME using env var as both
        secrets_defs=$(printf '%s\n' "$fallback" | awk '{print $1"|"$1}')
        using_fallback=true
    fi

    # Build parallel arrays: catalog_names[], env_names[], items[]
    local -a catalog_names env_names items
    while IFS='|' read -r cname ename; do
        [[ -z "$cname" ]] && continue
        catalog_names+=("$cname")
        env_names+=("$ename")
        if server_secret_get "$server_name" "$cname" 2>/dev/null; then
            items+=("$IC_EDIT  $ename  ✓")
        else
            items+=("$IC_SECRET  $ename  ✗ missing")
        fi
    done <<< "$secrets_defs"
    items+=("$IC_BACK  Back")

    local chosen
    chosen=$(rofi_menu "$IC_SECRET  Secrets — $server_name" "${items[@]}") \
        || exec_back servers
    [[ -z "$chosen" || "$chosen" == *"Back"* ]] && exec_back servers

    # Match chosen line back to catalog_name by finding env_name in item text
    local selected_cname="" selected_ename=""
    for i in "${!env_names[@]}"; do
        if [[ "$chosen" == *"${env_names[$i]}"* ]]; then
            selected_cname="${catalog_names[$i]}"
            selected_ename="${env_names[$i]}"
            break
        fi
    done
    [[ -z "$selected_cname" ]] && exec "$0" servers_secrets "$server_name"

    local is_set=false
    server_secret_get "$server_name" "$selected_cname" 2>/dev/null && is_set=true

    # Action submenu
    local action
    if $is_set; then
        action=$(printf '%s\n' \
            "$IC_EDIT     Update value" \
            "$IC_DEL      Remove" \
            "$IC_BACK     Back" \
            | rofi_menu "$IC_SECRET  $selected_ename  [set]") \
            || exec "$0" servers_secrets "$server_name"
    else
        action=$(printf '%s\n' \
            "$IC_ENABLE  Set value" \
            "$IC_BACK    Back" \
            | rofi_menu "$IC_SECRET  $selected_ename  [missing]") \
            || exec "$0" servers_secrets "$server_name"
    fi

    [[ -z "$action" || "$action" == *"Back"* ]] && exec "$0" servers_secrets "$server_name"

    case "$action" in
        *"Update"*|*"Set"*)
            local value
            value=$(secret_input_terminal "$selected_ename")
            if [[ -n "$value" ]]; then
                server_secret_set "$server_name" "$selected_cname" "$value"
                notify_ok "$selected_ename saved"
            fi
            exec "$0" servers_secrets "$server_name"
            ;;
        *"Remove"*)
            server_secret_rm "$server_name" "$selected_cname"
            notify_ok "$selected_ename removed"
            exec "$0" servers_secrets "$server_name"
            ;;
    esac
}

# ── menus ─────────────────────────────────────────────────────

menu_main() {
    local chosen
    chosen=$(printf '%s\n' \
        "$IC_CATALOG  Catalog" \
        "$IC_SERVER  Enabled Servers" \
        "$IC_CLIENT  Clients" \
        "$IC_TOOLS  Tools" \
        "$IC_GATEWAY  Gateway" \
        | rofi_menu "$IC_MAIN  Docker MCP") || exit 0
    [[ -z "$chosen" ]] && exit 0

    case "$chosen" in
        *Catalog*)           exec_back catalog ;;
        *"Enabled Servers"*) exec_back servers ;;
        *Clients*)           exec_back clients ;;
        *Tools*)             exec_back tools ;;
        *Gateway*)           exec_back gateway ;;
    esac
}

menu_catalog() {
    local names chosen name action
    names=$(catalog_names) || { notify_err "Failed to load catalog"; exec_back; }

    chosen=$(printf '%s\n' "$names" | rofi_menu "$IC_CATALOG  Catalog") || exec_back
    [[ -z "$chosen" ]] && exec_back
    name="${chosen%% *}"

    action=$(printf '%s\n' \
        "$IC_INFO  Info & Tools" \
        "$IC_ENABLE  Enable $name" \
        "$IC_BACK  Back" \
        | rofi_menu "$IC_CATALOG  $name") || exec_back catalog

    case "$action" in
        *"Info"*)
            show_server_info "$name"
            exec_back catalog
            ;;
        *Enable*)
            if docker mcp server enable "$name" >/dev/null 2>&1; then
                notify_ok "$name enabled"
            else
                notify_err "Failed to enable $name"
            fi
            exec_back catalog
            ;;
        *) exec_back catalog ;;
    esac
}

menu_servers() {
    local names chosen name action
    names=$(server_names) || { notify_err "Failed to list servers"; exec_back; }

    if [[ -z "$names" ]]; then
        notify_ok "No servers enabled. Browse Catalog first."
        exec_back
    fi

    chosen=$(printf '%s\n' "$names" | rofi_menu "$IC_SERVER  Enabled Servers") || exec_back
    [[ -z "$chosen" ]] && exec_back
    name="${chosen%% *}"

    action=$(printf '%s\n' \
        "$IC_INFO  Info & Tools" \
        "$IC_SECRET  Secrets" \
        "$IC_DISABLE  Disable $name" \
        "$IC_BACK  Back" \
        | rofi_menu "$IC_SERVER  $name") || exec_back servers

    case "$action" in
        *"Info"*)
            show_server_info "$name"
            exec_back servers
            ;;
        *Secrets*)
            exec "$0" servers_secrets "$name"
            ;;
        *Disable*)
            if docker mcp server disable "$name" >/dev/null 2>&1; then
                notify_ok "$name disabled"
            else
                notify_err "Failed to disable $name"
            fi
            exec_back servers
            ;;
        *) exec_back servers ;;
    esac
}

menu_clients() {
    local status_raw
    status_raw=$(docker mcp client ls --global 2>/dev/null \
        | sed 's/\x1b\[[0-9;]*m//g') || status_raw=""

    local items=() client
    for client in $SUPPORTED_CLIENTS; do
        local line
        line=$(printf '%s\n' "$status_raw" | grep "● $client:" || true)
        if printf '%s\n' "$line" | grep -qE ": connected"; then
            items+=("$IC_ENABLE  $client  [connected]")
        elif printf '%s\n' "$line" | grep -qE ": disconnected"; then
            items+=("$IC_DISABLE  $client")
        else
            items+=("$IC_CLIENT  $client")
        fi
    done

    local chosen name action
    chosen=$(printf '%s\n' "${items[@]}" \
        | rofi_menu "$IC_CLIENT  Clients") || exec_back
    [[ -z "$chosen" ]] && exec_back

    name=$(printf '%s' "$chosen" | grep -oE '[a-z][a-z0-9_-]+' | head -1)
    [[ -z "$name" ]] && exec_back clients

    local is_connected=false
    [[ "$chosen" == *"[connected]"* ]] && is_connected=true

    local action out
    if $is_connected; then
        action=$(printf '%s\n' \
            "$IC_DISABLE  Disconnect $name" \
            "$IC_BACK  Back" \
            | rofi_menu "$IC_CLIENT  $name  [connected]") || exec_back clients
    else
        action=$(printf '%s\n' \
            "$IC_ENABLE  Connect $name" \
            "$IC_BACK  Back" \
            | rofi_menu "$IC_CLIENT  $name") || exec_back clients
    fi

    case "$action" in
        *Connect*)
            out=$(docker mcp client connect --global "$name" 2>&1) && \
                notify_ok "$name connected – restart $name to apply" || \
                notify_err "$(printf '%s' "$out" | sed 's/\x1b\[[0-9;]*m//g' | grep -v '^===' | tail -2)"
            exec_back clients
            ;;
        *Disconnect*)
            out=$(docker mcp client disconnect --global "$name" 2>&1) && \
                notify_ok "$name disconnected" || \
                notify_err "$(printf '%s' "$out" | sed 's/\x1b\[[0-9;]*m//g' | grep -v '^===' | tail -2)"
            exec_back clients
            ;;
        *) exec_back clients ;;
    esac
}

menu_tools() {
    local names chosen name action
    names=$(tool_names) || { notify_err "Failed to list tools"; exec_back; }

    if [[ -z "$names" ]]; then
        notify_ok "No tools available – enable servers first."
        exec_back
    fi

    chosen=$(printf '%s\n' "$names" | rofi_menu "$IC_TOOLS  Tools") || exec_back
    [[ -z "$chosen" ]] && exec_back
    name="${chosen%% *}"

    action=$(printf '%s\n' \
        "$IC_INSPECT  Inspect $name" \
        "$IC_BACK  Back" \
        | rofi_menu "$IC_TOOLS  $name") || exec_back tools

    case "$action" in
        *Inspect*)
            show_in_terminal "MCP Tool — $name" \
                "docker mcp tools inspect '$name' 2>&1"
            ;;
        *) exec_back tools ;;
    esac
}

menu_gateway() {
    local chosen
    chosen=$(printf '%s\n' \
        "$IC_ENABLE  Start Gateway" \
        "$IC_TOOLS  Count Tools" \
        "$IC_BACK  Back" \
        | rofi_menu "$IC_GATEWAY  Gateway") || exec_back

    case "$chosen" in
        *"Start Gateway"*)
            show_in_terminal "MCP Gateway" "docker mcp gateway run"
            ;;
        *"Count Tools"*)
            show_in_terminal "MCP Tools" \
                "docker mcp tools count 2>&1; echo; docker mcp tools ls 2>&1"
            ;;
        *) exec_back ;;
    esac
}

# ── dispatch ──────────────────────────────────────────────────
preflight

case "${1:-}" in
    catalog)         menu_catalog ;;
    servers)         menu_servers ;;
    servers_secrets) menu_server_secrets "${2:-}" ;;
    clients)         menu_clients ;;
    tools)           menu_tools ;;
    gateway)         menu_gateway ;;
    *)               menu_main ;;
esac
