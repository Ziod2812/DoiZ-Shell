#!/bin/sh

mode="$1"

if [ "$mode" = "name" ]; then
    if command -v nvidia-smi >/dev/null 2>&1; then
        n=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1)
        if [ -n "$n" ]; then
            printf '%s\n' "$n"
            exit 0
        fi
    fi

    n=$(lspci -mm 2>/dev/null | awk -F'"' '/VGA|3D|Display/ { print $4 " " $6; exit }')

    if [ -z "$n" ]; then
        for c in /sys/class/drm/card[0-9]; do
            n=$(basename "$(readlink "$c/device/driver" 2>/dev/null)")
            [ -n "$n" ] && break
        done
    fi

    printf '%s\n' "$n"
    exit 0
fi

usage=""
temp=""
vused=""
vtotal=""
freq=""

if command -v nvidia-smi >/dev/null 2>&1; then
    row=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | head -n1 | tr -d ' ')

    if [ -n "$row" ]; then
        usage=$(printf '%s' "$row" | cut -d, -f1)
        temp=$(printf '%s' "$row" | cut -d, -f2)
        vused=$(printf '%s' "$row" | cut -d, -f3)
        vtotal=$(printf '%s' "$row" | cut -d, -f4)
    fi
else
    pick=""

    for c in /sys/class/drm/card[0-9]; do
        [ -d "$c/device" ] || continue
        [ -z "$pick" ] && pick="$c"

        if [ -r "$c/device/gpu_busy_percent" ]; then
            pick="$c"
            break
        fi
    done

    if [ -n "$pick" ]; then
        d="$pick/device"

        [ -r "$d/gpu_busy_percent" ] && usage=$(cat "$d/gpu_busy_percent" 2>/dev/null)

        if [ -r "$d/mem_info_vram_used" ] && [ -r "$d/mem_info_vram_total" ]; then
            vused=$(( $(cat "$d/mem_info_vram_used") / 1048576 ))
            vtotal=$(( $(cat "$d/mem_info_vram_total") / 1048576 ))
        fi

        for h in "$d"/hwmon/hwmon*/temp1_input; do
            if [ -r "$h" ]; then
                temp=$(( $(cat "$h") / 1000 ))
                break
            fi
        done

        [ -r "$pick/gt_cur_freq_mhz" ] && freq=$(cat "$pick/gt_cur_freq_mhz" 2>/dev/null)
    fi
fi

printf '%s\n' \
    "USAGE=$usage" \
    "TEMP=$temp" \
    "VRAM_USED=$vused" \
    "VRAM_TOTAL=$vtotal" \
    "FREQ=$freq"
