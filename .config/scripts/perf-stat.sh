#!/usr/bin/env bash
# perf-stat.sh — emits 1-line JSON/sek for quickshell PerfState.
#
# Schema:
#   {"ts":<unix>,"cpu":<0..1>,"cpuPerCore":[<0..1>,...],
#    "memUsed":<bytes>,"memTotal":<bytes>,
#    "temps":[{"name":"...","value":<°C>,"label":"..."},...],
#    "net":{"iface":"...","rxKbps":<n>,"txKbps":<n>},
#    "disk":{"readKbps":<n>,"writeKbps":<n>},
#    "gpu":{"backend":"<nvidia|amd|amdgpu|intel|none>",
#           "name":"...","busy":<0..1|null>,
#           "memUsed":<bytes|null>,"memTotal":<bytes|null>,
#           "temp":<°C|null>}}
#
# Single bash process held alive by Quickshell Process (running=true).
# State kept in shell vars across loop iterations → no temp files.

INTERVAL="${PERF_STAT_INTERVAL:-1}"

# ── CPU prev sample (per-core + total) ──────────────────────────────
declare -A CPU_PREV_BUSY CPU_PREV_TOTAL

read_cpu_line() {
    # $1=key (e.g. "cpu" or "cpu0"); echoes "busy total" delta-percent for that key
    local key="$1" line user nice system idle iowait irq softirq steal busy total
    line=$(grep "^${key} " /proc/stat 2>/dev/null) || return 1
    # shellcheck disable=SC2086
    set -- $line
    user=$2; nice=$3; system=$4; idle=$5
    iowait=${6:-0}; irq=${7:-0}; softirq=${8:-0}; steal=${9:-0}
    busy=$(( user + nice + system + irq + softirq + steal ))
    total=$(( busy + idle + iowait ))
    local prev_busy=${CPU_PREV_BUSY[$key]:-0}
    local prev_total=${CPU_PREV_TOTAL[$key]:-0}
    local d_busy=$(( busy - prev_busy ))
    local d_total=$(( total - prev_total ))
    CPU_PREV_BUSY[$key]=$busy
    CPU_PREV_TOTAL[$key]=$total
    if (( d_total > 0 )); then
        awk -v b=$d_busy -v t=$d_total 'BEGIN{printf "%.4f", b/t}'
    else
        echo "0"
    fi
}

# ── Net prev sample ─────────────────────────────────────────────────
NET_PREV_RX=0; NET_PREV_TX=0; NET_PREV_TS=0
NET_IFACE=""

# Pick primary iface: first non-skip iface with UP+LOWER_UP and non-zero rx.
# Cache choice for 5 sec to avoid flipping each tick.
NET_PICK_TS=0
pick_net_iface() {
    local now=$1
    if (( now - NET_PICK_TS < 5 )) && [[ -n "$NET_IFACE" ]]; then
        return
    fi
    NET_PICK_TS=$now
    local cand="" line iface flags rest
    while read -r line; do
        iface=${line%%:*}
        iface=${iface// /}
        case "$iface" in
            lo|docker*|veth*|br-*|virbr*|tailscale*|wg*|tun*) continue ;;
        esac
        # Only consider ifaces with carrier
        [[ -f /sys/class/net/$iface/carrier ]] || continue
        [[ "$(cat /sys/class/net/$iface/carrier 2>/dev/null)" == "1" ]] || continue
        cand=$iface
        break
    done < <(tail -n +3 /proc/net/dev)
    if [[ -n "$cand" && "$cand" != "$NET_IFACE" ]]; then
        NET_IFACE=$cand
        NET_PREV_RX=0; NET_PREV_TX=0; NET_PREV_TS=0
    fi
}

read_net() {
    local now=$1
    pick_net_iface "$now"
    if [[ -z "$NET_IFACE" ]]; then
        echo "\"\" 0 0"; return
    fi
    local line rx tx
    line=$(grep -E "^[[:space:]]*${NET_IFACE}:" /proc/net/dev 2>/dev/null) || { echo "\"\" 0 0"; return; }
    # iface: rx_bytes pkts errs drop fifo frame compr mcast tx_bytes pkts ...
    # shellcheck disable=SC2086
    set -- $line
    rx=$2; tx=${10}
    local rx_kbps=0 tx_kbps=0
    local dt=$(( now - NET_PREV_TS ))
    if (( NET_PREV_TS > 0 && dt > 0 )); then
        local d_rx=$(( rx - NET_PREV_RX ))
        local d_tx=$(( tx - NET_PREV_TX ))
        # bytes/sec → KiB/s
        rx_kbps=$(awk -v b=$d_rx -v t=$dt 'BEGIN{printf "%.1f", b/1024/t}')
        tx_kbps=$(awk -v b=$d_tx -v t=$dt 'BEGIN{printf "%.1f", b/1024/t}')
    fi
    NET_PREV_RX=$rx; NET_PREV_TX=$tx; NET_PREV_TS=$now
    echo "\"$NET_IFACE\" $rx_kbps $tx_kbps"
}

# ── Disk prev sample (aggregated across non-virtual block devices) ──
DISK_PREV_R=0; DISK_PREV_W=0; DISK_PREV_TS=0

read_disk() {
    local now=$1
    local total_r=0 total_w=0 dev stat_line r_sec w_sec
    for dev in /sys/block/*; do
        local name=${dev##*/}
        case "$name" in
            loop*|ram*|sr*|dm-*|zram*) continue ;;
        esac
        [[ -f "$dev/stat" ]] || continue
        read -r stat_line < "$dev/stat"
        # fields: read_ios read_merges read_sectors read_ticks write_ios write_merges write_sectors ...
        # shellcheck disable=SC2086
        set -- $stat_line
        r_sec=$3; w_sec=$7
        total_r=$(( total_r + r_sec ))
        total_w=$(( total_w + w_sec ))
    done
    local r_kbps=0 w_kbps=0
    local dt=$(( now - DISK_PREV_TS ))
    if (( DISK_PREV_TS > 0 && dt > 0 )); then
        local d_r=$(( total_r - DISK_PREV_R ))
        local d_w=$(( total_w - DISK_PREV_W ))
        # 512-byte sectors → KiB/s
        r_kbps=$(awk -v s=$d_r -v t=$dt 'BEGIN{printf "%.1f", s*512/1024/t}')
        w_kbps=$(awk -v s=$d_w -v t=$dt 'BEGIN{printf "%.1f", s*512/1024/t}')
    fi
    DISK_PREV_R=$total_r; DISK_PREV_W=$total_w; DISK_PREV_TS=$now
    echo "$r_kbps $w_kbps"
}

# ── Memory ──────────────────────────────────────────────────────────
read_mem() {
    # outputs: "used_bytes total_bytes"
    local total avail
    while IFS=': ' read -r key val _; do
        case "$key" in
            MemTotal)     total=$(( val * 1024 )) ;;
            MemAvailable) avail=$(( val * 1024 )) ;;
        esac
    done < /proc/meminfo
    echo "$(( total - avail )) $total"
}

# ── Temps (enumerate /sys/class/hwmon/*) ────────────────────────────
# Cache hwmon-list discovery once (sysfs structure is stable per boot).
TEMP_SOURCES=()
discover_temps() {
    TEMP_SOURCES=()
    local h name f label
    for h in /sys/class/hwmon/hwmon*; do
        [[ -d "$h" ]] || continue
        name=$(cat "$h/name" 2>/dev/null || echo "?")
        # Skip non-thermal sensors (power_supply nodes etc)
        case "$name" in
            AC|BAT*|ucsi*) continue ;;
        esac
        for f in "$h"/temp*_input; do
            [[ -f "$f" ]] || continue
            local idx=${f##*/temp}; idx=${idx%_input}
            label=""
            [[ -f "$h/temp${idx}_label" ]] && label=$(cat "$h/temp${idx}_label" 2>/dev/null)
            TEMP_SOURCES+=("$name|$label|$f")
        done
    done
}
discover_temps

read_temps_json() {
    local out="" first=1 entry name label path val
    for entry in "${TEMP_SOURCES[@]}"; do
        name=${entry%%|*}; entry=${entry#*|}
        label=${entry%%|*}; path=${entry#*|}
        [[ -r "$path" ]] || continue
        # Use cat: some sysfs sensors (e.g. iwlwifi when radio asleep) return
        # ENODEV on read() — bash `read <` propagates as a noisy error; cat
        # silences it cleanly and we just skip the empty result.
        val=$(cat "$path" 2>/dev/null)
        [[ -z "$val" ]] && continue
        # millidegrees → degrees
        val=$(awk -v v=$val 'BEGIN{printf "%.1f", v/1000}')
        # Skip implausible (sensor errors)
        awk -v v=$val 'BEGIN{exit !(v>0 && v<150)}' || continue
        local lbl_json=${label:-""}
        if (( first )); then first=0; else out+=","; fi
        out+="{\"name\":\"$name\",\"label\":\"$lbl_json\",\"value\":$val}"
    done
    echo "$out"
}

# ── GPU (detection chain, cached) ───────────────────────────────────
GPU_BACKEND=""
GPU_NAME=""
GPU_AMD_BUSY_PATH=""
GPU_AMD_VRAM_USED_PATH=""
GPU_AMD_VRAM_TOTAL_PATH=""
GPU_AMD_TEMP_PATH=""
GPU_INTEL_CUR=""
GPU_INTEL_MAX=""

detect_gpu() {
    GPU_BACKEND="none"; GPU_NAME=""
    if command -v nvidia-smi >/dev/null 2>&1; then
        # Verify nvidia-smi can actually query a GPU (driver loaded)
        if nvidia-smi -L 2>/dev/null | grep -q '^GPU'; then
            GPU_BACKEND="nvidia"
            GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits 2>/dev/null | head -1)
            return
        fi
    fi
    # AMD via amdgpu sysfs
    local card
    for card in /sys/class/drm/card[0-9]; do
        [[ -d "$card/device" ]] || continue
        local drv
        drv=$(basename "$(readlink -f "$card/device/driver" 2>/dev/null)" 2>/dev/null || echo "")
        if [[ "$drv" == "amdgpu" ]]; then
            GPU_BACKEND="amd"
            GPU_AMD_BUSY_PATH="$card/device/gpu_busy_percent"
            GPU_AMD_VRAM_USED_PATH="$card/device/mem_info_vram_used"
            GPU_AMD_VRAM_TOTAL_PATH="$card/device/mem_info_vram_total"
            # AMD temp typically under hwmon attached to card
            local h
            for h in "$card/device/hwmon/"hwmon*/temp1_input; do
                [[ -f "$h" ]] && GPU_AMD_TEMP_PATH="$h" && break
            done
            GPU_NAME=$(cat "$card/device/product_name" 2>/dev/null || \
                       lspci 2>/dev/null | grep -m1 -iE 'vga|3d.*amd' | sed 's/.*: //; s/ (rev.*//')
            return
        elif [[ "$drv" == "i915" || "$drv" == "xe" ]]; then
            GPU_BACKEND="intel"
            GPU_INTEL_CUR="$card/gt_cur_freq_mhz"
            GPU_INTEL_MAX="$card/gt_max_freq_mhz"
            GPU_NAME=$(lspci 2>/dev/null | grep -m1 -iE 'vga|3d.*intel' | sed 's/.*: //; s/ (rev.*//')
            return
        fi
    done
}
detect_gpu

read_gpu_json() {
    case "$GPU_BACKEND" in
        nvidia)
            # busy_percent,mem_used_MiB,mem_total_MiB,temp_C
            local line busy used total temp
            line=$(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu \
                              --format=csv,noheader,nounits 2>/dev/null | head -1)
            if [[ -n "$line" ]]; then
                busy=${line%%,*}; line=${line#*, }
                used=${line%%,*}; line=${line#*, }
                total=${line%%,*}; line=${line#*, }
                temp=${line%%,*}
                # MiB → bytes
                used=$(( ${used// /} * 1024 * 1024 ))
                total=$(( ${total// /} * 1024 * 1024 ))
                busy=$(awk -v v=${busy// /} 'BEGIN{printf "%.4f", v/100}')
                temp=${temp// /}
                printf '"nvidia",%s,%s,%s,%s' "$busy" "$used" "$total" "$temp"
                return
            fi
            printf '"nvidia",null,null,null,null'
            ;;
        amd)
            local busy_pct=null used=null total=null temp=null v
            if [[ -r "$GPU_AMD_BUSY_PATH" ]]; then
                read -r v < "$GPU_AMD_BUSY_PATH"
                busy_pct=$(awk -v v=$v 'BEGIN{printf "%.4f", v/100}')
            fi
            [[ -r "$GPU_AMD_VRAM_USED_PATH" ]] && read -r used < "$GPU_AMD_VRAM_USED_PATH"
            [[ -r "$GPU_AMD_VRAM_TOTAL_PATH" ]] && read -r total < "$GPU_AMD_VRAM_TOTAL_PATH"
            if [[ -r "$GPU_AMD_TEMP_PATH" ]]; then
                read -r v < "$GPU_AMD_TEMP_PATH"
                temp=$(awk -v v=$v 'BEGIN{printf "%.1f", v/1000}')
            fi
            printf '"amd",%s,%s,%s,%s' "$busy_pct" "$used" "$total" "$temp"
            ;;
        intel)
            # No native busy% without intel_gpu_top (needs root). Report freq ratio.
            local cur=0 max=1
            [[ -r "$GPU_INTEL_CUR" ]] && read -r cur < "$GPU_INTEL_CUR"
            [[ -r "$GPU_INTEL_MAX" ]] && read -r max < "$GPU_INTEL_MAX"
            local busy_pct=null
            if (( max > 0 )); then
                busy_pct=$(awk -v c=$cur -v m=$max 'BEGIN{printf "%.4f", c/m}')
            fi
            printf '"intel",%s,null,null,null' "$busy_pct"
            ;;
        *)
            printf '"none",null,null,null,null'
            ;;
    esac
}

# Initial sample (no delta yet; throws away t=0 readout).
NOW=$(date +%s)
read_cpu_line "cpu" >/dev/null
read_net "$NOW" >/dev/null
read_disk "$NOW" >/dev/null

CORE_KEYS=()
for c in /sys/devices/system/cpu/cpu[0-9]*; do
    n=${c##*/cpu}
    [[ "$n" =~ ^[0-9]+$ ]] || continue
    CORE_KEYS+=("cpu$n")
    read_cpu_line "cpu$n" >/dev/null
done

sleep "$INTERVAL"

while :; do
    NOW=$(date +%s)

    cpu_total=$(read_cpu_line "cpu")
    per_core="["
    first=1
    for k in "${CORE_KEYS[@]}"; do
        v=$(read_cpu_line "$k")
        if (( first )); then first=0; else per_core+=","; fi
        per_core+="$v"
    done
    per_core+="]"

    read -r mem_used mem_total <<< "$(read_mem)"
    read -r r_kbps w_kbps <<< "$(read_disk "$NOW")"
    read -r iface_q rx_k tx_k <<< "$(read_net "$NOW")"
    temps_json=$(read_temps_json)
    gpu_json=$(read_gpu_json)
    # gpu_json fields: "backend",busy,memUsed,memTotal,temp
    IFS=, read -r g_backend g_busy g_mu g_mt g_temp <<< "$gpu_json"

    printf '{"ts":%d,"cpu":%s,"cpuPerCore":%s,"memUsed":%s,"memTotal":%s,"temps":[%s],"net":{"iface":%s,"rxKbps":%s,"txKbps":%s},"disk":{"readKbps":%s,"writeKbps":%s},"gpu":{"backend":%s,"name":"%s","busy":%s,"memUsed":%s,"memTotal":%s,"temp":%s}}\n' \
        "$NOW" "$cpu_total" "$per_core" "$mem_used" "$mem_total" "$temps_json" \
        "$iface_q" "$rx_k" "$tx_k" "$r_kbps" "$w_kbps" \
        "$g_backend" "$GPU_NAME" "$g_busy" "$g_mu" "$g_mt" "$g_temp"

    sleep "$INTERVAL"
done
