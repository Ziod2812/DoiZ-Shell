#!/usr/bin/env bash
export LC_ALL=C

read -r _ u1 n1 s1 i1 w1 q1 sq1 _ < /proc/stat
sleep 0.4
read -r _ u2 n2 s2 i2 w2 q2 sq2 _ < /proc/stat
t1=$((u1 + n1 + s1 + i1 + w1 + q1 + sq1))
t2=$((u2 + n2 + s2 + i2 + w2 + q2 + sq2))
dt=$((t2 - t1))
di=$(((i2 + w2) - (i1 + w1)))
cpu=0
[ "$dt" -gt 0 ] && cpu=$(((dt - di) * 100 / dt))

cpu_name=$(awk -F: '/^model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo)
cpu_name=$(printf '%s' "$cpu_name" | sed -E 's/\((R|TM)\)//g; s/ (CPU|Processor)//g; s/ @.*//; s/ +/ /g')
cpu_cores=$(grep -c '^processor' /proc/cpuinfo)
cpu_freq=$(awk -F: '/^cpu MHz/ {s+=$2; n++} END {if (n) printf "%.2f GHz", s/n/1000}' /proc/cpuinfo)

cpu_temp=""
for h in /sys/class/hwmon/hwmon*; do
    [ -r "$h/name" ] || continue
    case "$(cat "$h/name")" in
        k10temp|coretemp|zenpower|cpu_thermal)
            for f in "$h"/temp1_input; do
                [ -r "$f" ] && cpu_temp=$(($(cat "$f") / 1000))
            done
            [ -n "$cpu_temp" ] && break
            ;;
    esac
done
if [ -z "$cpu_temp" ]; then
    for z in /sys/class/thermal/thermal_zone*; do
        [ -r "$z/temp" ] || continue
        cpu_temp=$(($(cat "$z/temp") / 1000))
        break
    done
fi

gpu_found=0; gpu_name=""; gpu_usage=""; gpu_temp=""; vram_used=""; vram_total=""; gpu_freq=""; gpu_shared=0

if command -v nvidia-smi >/dev/null 2>&1; then
    row=$(nvidia-smi --query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total \
        --format=csv,noheader,nounits 2>/dev/null | head -n 1)
    if [ -n "$row" ]; then
        gpu_found=1
        IFS=',' read -r gpu_name gpu_usage gpu_temp vram_used vram_total <<<"$row"
        gpu_name=$(printf '%s' "$gpu_name" | sed -E 's/^ +| +$//g; s/^NVIDIA //; s/GeForce //')
        gpu_usage=${gpu_usage// /}; gpu_temp=${gpu_temp// /}
        vram_used=${vram_used// /}; vram_total=${vram_total// /}
    fi
fi

if [ "$gpu_found" = 0 ]; then
    for d in /sys/class/drm/card[0-9]*/device; do
        [ -r "$d/vendor" ] || continue
        if [ -r "$d/gpu_busy_percent" ]; then
            gpu_found=1
            gpu_usage=$(cat "$d/gpu_busy_percent")
            [ -r "$d/mem_info_vram_used" ] && vram_used=$(($(cat "$d/mem_info_vram_used") / 1048576))
            [ -r "$d/mem_info_vram_total" ] && vram_total=$(($(cat "$d/mem_info_vram_total") / 1048576))
            for t in "$d"/hwmon/hwmon*/temp1_input; do
                [ -r "$t" ] && gpu_temp=$(($(cat "$t") / 1000))
            done
            slot=$(sed -n 's/^PCI_SLOT_NAME=//p' "$d/uevent" 2>/dev/null)
            if [ -n "$slot" ] && command -v lspci >/dev/null 2>&1; then
                gpu_name=$(lspci -s "$slot" 2>/dev/null | sed -E 's/.*\[([^]]*)\][^[]*$/\1/; s/.*: //')
            fi
            [ -n "$gpu_name" ] || gpu_name="AMD GPU"
            break
        elif [ "$(cat "$d/vendor")" = "0x8086" ]; then
            gpu_found=1
            gpu_shared=1
            gpu_name="Intel Graphics"
            card=${d%/device}
            act=""; max=""
            for f in "$card/gt_act_freq_mhz" "$card/gt/gt0/rps_act_freq_mhz" "$d/tile0/gt0/freq0/act_freq"; do
                [ -r "$f" ] && { act=$(cat "$f" 2>/dev/null); break; }
            done
            for f in "$card/gt_max_freq_mhz" "$card/gt/gt0/rps_max_freq_mhz" "$d/tile0/gt0/freq0/max_freq"; do
                [ -r "$f" ] && { max=$(cat "$f" 2>/dev/null); break; }
            done
            if [ -n "$act" ] && [ -n "$max" ] && [ "$max" -gt 0 ] 2>/dev/null; then
                gpu_freq="${act} MHz"
                gpu_usage=$((act * 100 / max))
            fi
            for t in "$d"/hwmon/hwmon*/temp1_input; do
                [ -r "$t" ] && gpu_temp=$(($(cat "$t") / 1000))
            done
            [ -n "$gpu_temp" ] || gpu_temp=$cpu_temp
            break
        fi
    done
fi

read -r ram_total ram_avail swap_total swap_free < <(awk '
    /^MemTotal/ {t=$2} /^MemAvailable/ {a=$2}
    /^SwapTotal/ {st=$2} /^SwapFree/ {sf=$2}
    END {print t+0, a+0, st+0, sf+0}' /proc/meminfo)

printf 'CPU=%s\nCPU_NAME=%s\nCPU_CORES=%s\nCPU_FREQ=%s\nCPU_TEMP=%s\n' \
    "$cpu" "$cpu_name" "$cpu_cores" "${cpu_freq:---}" "${cpu_temp:--1}"
printf 'GPU_FOUND=%s\nGPU_NAME=%s\nGPU_USAGE=%s\nGPU_TEMP=%s\nVRAM_USED=%s\nVRAM_TOTAL=%s\nGPU_FREQ=%s\nGPU_SHARED=%s\n' \
    "$gpu_found" "$gpu_name" "${gpu_usage:--1}" "${gpu_temp:--1}" "${vram_used:--1}" "${vram_total:--1}" "$gpu_freq" "$gpu_shared"
printf 'RAM_TOTAL=%s\nRAM_USED=%s\nSWAP_TOTAL=%s\nSWAP_USED=%s\n' \
    "$ram_total" "$((ram_total - ram_avail))" "$swap_total" "$((swap_total - swap_free))"
