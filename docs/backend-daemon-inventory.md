# Backend Daemon Inventory (P2)

Question: should the shell's script-driven backend be replaced by a real
long-running program (a daemon, à la DankMaterialShell's Go backend) for speed,
reliability, and persistent state?

This inventory classifies every script the shell shells out to, then answers it.

## Classification

Each script is tagged:
- **native** — Quickshell already provides this event-driven; no backend needed
- **one-shot** — fire-and-forget action; a daemon adds nothing
- **external-theming** — themes *other apps* (niri/starship/zen) via wallust; not shell backend, and a daemon would still shell out to wallust
- **personal** — user convenience (package mgmt); not shell-core, belongs in the personal layer
- **poller** — genuinely long-running; the only real daemon candidate

| Script | Function | Class |
|---|---|---|
| `perf-stat.sh` | 1 Hz CPU/mem/temp/net/disk/gpu JSON for PerfState | **poller** |
| `wallpaper_switcher.sh` | apply wallpaper (awww) + wallust regen | external-theming / one-shot |
| `wallpaper-thumb-gen.sh` | thumbnail batch gen | one-shot |
| `pywal-niri-colors.sh` | rewrite niri border colors | external-theming |
| `starship-color-gen.sh` | starship palette | external-theming |
| `zen-wal-refresh.sh` | zen browser colors | external-theming |
| `pick-color.sh` | niri pick-color → clipboard + toast | one-shot |
| `qs-osd.sh` | niri keybind → qs OSD IPC | one-shot |
| `screenshot-window-pick.sh`, `screenrecord.sh`, `snapshot.sh` | grim/slurp/record | one-shot |
| `kanshi-lid-watcher.sh` | lid → kanshi profile | one-shot watcher (kanshi owns most) |
| `restore-charge-threshold.sh` | restore battery threshold at boot | one-shot (boot hook) |
| `installer/*` (pkg/webapp/system-update) | yay-in-kitty package mgmt | **personal** |
| `fastfetch-launcher`, `fzf-tmux`, `git-logs`, `open_notes`, `zed-dropterm-task` | terminal/dev helpers | one-shot, unrelated |

Event-driven system state the shell already gets **native** from Quickshell —
no script, no daemon: battery/power (`Quickshell.Services.UPower`), network
(`Quickshell.Networking`), bluetooth, MPRIS, system tray.

## Verdict: a daemon does NOT earn its keep

1. **Almost everything is one-shot or external-app theming.** A daemon helps
   neither — one-shots gain nothing from a resident process, and theming hooks
   would still shell out to `wallust`. A daemon would *relocate* bash, not
   remove it (the external binaries — wallust, awww, grim, kanshi — stay).

2. **Only one genuine long-running workload: `perf-stat.sh`.** And it already
   runs as a persistent process (held alive by Quickshell `Process{ running:true }`),
   keeping sample state in shell vars across ticks. Rewriting it in Go/Rust buys
   marginal efficiency + type-safety — *not a new capability*.

3. **"Persistent state" needs no daemon.** The only persistent state is the
   battery threshold (already a file in `~/.local/state/quickshell/`) and last
   wallpaper/theme (already files). A state file + `FileView` already does this.

4. **Quickshell already is the event backend.** UPower/Network/Bluetooth/MPRIS/
   Tray are native. DankMaterialShell's Go backend exists because it does *more*
   (cross-compositor integration + system stats); on niri you get compositor
   data free from `niri msg` IPC, so that justification doesn't transfer.

This matches the Noctalia model (pure Quickshell, no daemon) rather than DMS.

## Recommendation

**Do not build a backend daemon.** Keep the thin scripts.

If `perf-stat.sh`'s `/proc` + `awk` parsing ever proves too slow or flaky,
rewrite **only that one script** as a small focused typed binary (Go/Rust) that
emits the same JSON line protocol — a single tool swap behind the existing
`PerfState` contract, not a backend architecture. That is the entire surface
where a compiled program would pay off.

Separately (not daemon-related): `installer/*` are personal-convenience actions,
not shell-core — they belong in the personal config layer, kept out of any
future extracted shell.
