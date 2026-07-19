#!/usr/bin/env bash
# kanshi-lid-watcher — switch kanshi profile based on lid + dock state.
# Manages a systemd-inhibit so logind only suspends when undocked.

set -u

LID=""
for f in /proc/acpi/button/lid/*/state; do LID="$f"; break; done
if [[ -z "$LID" ]]; then
    echo "kanshi-lid-watcher: no /proc/acpi/button/lid/*/state, exiting" >&2
    exit 0
fi

INHIBIT_PID=""
start_inhibit() {
    if [[ -z "$INHIBIT_PID" ]] || ! kill -0 "$INHIBIT_PID" 2>/dev/null; then
        systemd-inhibit \
            --what=handle-lid-switch \
            --who=kanshi-lid-watcher \
            --why="external monitors attached" \
            --mode=block \
            sleep infinity &
        INHIBIT_PID=$!
    fi
}
stop_inhibit() {
    if [[ -n "$INHIBIT_PID" ]] && kill -0 "$INHIBIT_PID" 2>/dev/null; then
        kill "$INHIBIT_PID" 2>/dev/null || true
    fi
    INHIBIT_PID=""
}
trap 'stop_inhibit' EXIT INT TERM

externals_present() {
    niri msg --json outputs 2>/dev/null \
        | jq -e 'to_entries | any(.key | test("^(eDP|LVDS|DSI)"; "i") | not)' >/dev/null 2>&1
}

lid_state() {
    awk '{print $2}' "$LID" 2>/dev/null
}

apply() {
    local state ext
    state=$(lid_state)
    if externals_present; then ext=1; else ext=0; fi

    if [[ $ext -eq 1 ]]; then
        start_inhibit
        if [[ "$state" == "closed" ]]; then
            kanshictl switch docked_closed
        else
            kanshictl switch docked_open
        fi
    else
        stop_inhibit
        if [[ "$state" == "open" ]]; then
            kanshictl switch laptop_open
        fi
        # closed + no externals → logind handles suspend (inhibitor released).
    fi
}

# Wait for kanshi daemon to be ready (max ~5s).
# A fresh install intentionally contains only the fallback profile. Dock/lid
# switching becomes active after the user defines the three named profiles in
# ~/.config/kanshi/config for that machine.
for required_profile in docked_open docked_closed laptop_open; do
    grep -qE "^profile[[:space:]]+${required_profile}[[:space:]]*\\{" \
        "$HOME/.config/kanshi/config" 2>/dev/null || exit 0
done

for _ in 1 2 3 4 5 6 7 8 9 10; do
    kanshictl reload >/dev/null 2>&1 && break
    sleep 0.5
done

# Initial apply.
apply
last_state=$(lid_state)
last_ext=$(externals_present && echo 1 || echo 0)

while sleep 1; do
    cur_state=$(lid_state)
    cur_ext=$(externals_present && echo 1 || echo 0)
    if [[ "$cur_state" != "$last_state" || "$cur_ext" != "$last_ext" ]]; then
        sleep 0.4  # debounce hotplug bouncing
        apply
        last_state=$cur_state
        last_ext=$cur_ext
    fi
done
