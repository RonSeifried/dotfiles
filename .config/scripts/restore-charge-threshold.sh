#!/bin/sh
# Restore battery charge threshold from saved state.
# Invoked by systemd user service battery-threshold-restore.service.
# Sysfs files must be group-writable for `wheel` (see system/udev/99-charge-threshold.rules).

set -eu

state="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/battery-threshold"
[ -r "$state" ] || exit 0

end=$(cat "$state")
case "$end" in
  ''|*[!0-9]*) exit 0 ;;
esac
[ "$end" -ge 50 ] && [ "$end" -le 100 ] || exit 0

# end=100 means "no limit" — start=0 so battery always charges fully.
# Below 100: hysteresis of 5 to avoid micro-charging.
if [ "$end" -ge 100 ]; then
  start=0
else
  start=$(( end > 5 ? end - 5 : 0 ))
fi

for bat in /sys/class/power_supply/BAT*; do
  [ -w "$bat/charge_control_end_threshold" ] || continue
  # Write start first; on fresh boot defaults are 0/100 so start<100 succeeds, then end>=start+5 succeeds.
  echo "$start" > "$bat/charge_control_start_threshold" 2>/dev/null || true
  echo "$end"   > "$bat/charge_control_end_threshold"   2>/dev/null || true
  # Kick state machine: re-write start to force re-evaluation (driver may stay stuck in
  # "stopped" state if battery is between start and end at boot).
  kick=$(( end > 0 ? end - 1 : 0 ))
  echo "$kick"  > "$bat/charge_control_start_threshold" 2>/dev/null || true
  echo "$start" > "$bat/charge_control_start_threshold" 2>/dev/null || true
done
