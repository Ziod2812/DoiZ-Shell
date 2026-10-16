#!/bin/sh

b=""
for d in /sys/class/power_supply/*; do
    if [ -f "$d/type" ] && [ "$(cat "$d/type" 2>/dev/null)" = "Battery" ]; then
        b="$d"
        break
    fi
done

if [ -z "$b" ]; then
    echo "FOUND=0"
    exit 0
fi

readv() {
    cat "$b/$1" 2>/dev/null
}

status=$(readv status)
capacity=$(readv capacity)
cycles=$(readv cycle_count)
technology=$(readv technology)
model=$(readv model_name)
manufacturer=$(readv manufacturer)
voltage=$(readv voltage_now)
power=$(readv power_now)
current=$(readv current_now)
energy_now=$(readv energy_now)
energy_full=$(readv energy_full)
energy_design=$(readv energy_full_design)
charge_now=$(readv charge_now)
charge_full=$(readv charge_full)
charge_design=$(readv charge_full_design)

[ -n "$energy_now" ] || energy_now="$charge_now"
[ -n "$energy_full" ] || energy_full="$charge_full"
[ -n "$energy_design" ] || energy_design="$charge_design"

if [ -z "$power" ] && [ -n "$current" ] && [ -n "$voltage" ]; then
    power=$((current * voltage / 1000000))
fi

if [ -n "$voltage" ]; then
    voltage_text=$(awk -v v="$voltage" 'BEGIN {printf "%.2f V", v/1000000}')
else
    voltage_text="N/A"
fi

if [ -n "$power" ] && [ "$power" -gt 0 ] 2>/dev/null; then
    power_text=$(awk -v p="$power" 'BEGIN {printf "%.2f W", p/1000000}')
else
    power_text="0.00 W"
fi

if [ -n "$current" ] && [ "$current" -gt 0 ] 2>/dev/null; then
    current_text=$(awk -v c="$current" 'BEGIN {printf "%.2f A", c/1000000}')
else
    current_text="0.00 A"
fi

if [ -n "$energy_full" ] && [ -n "$energy_design" ] && [ "$energy_design" -gt 0 ] 2>/dev/null; then
    health="$((energy_full * 100 / energy_design))%"
    wear_text="$((100 - energy_full * 100 / energy_design))%"
else
    health="N/A"
    wear_text="N/A"
fi

if [ -n "$energy_full" ] && [ "$energy_full" -gt 0 ] 2>/dev/null; then
    full_capacity=$(awk -v e="$energy_full" 'BEGIN {printf "%.2f Wh", e/1000000}')
elif [ -n "$charge_full" ] && [ -n "$voltage" ]; then
    full_capacity=$(awk -v c="$charge_full" -v v="$voltage" 'BEGIN {printf "%.2f Wh", (c*v)/1000000000000}')
else
    full_capacity="N/A"
fi

if [ -n "$energy_design" ] && [ "$energy_design" -gt 0 ] 2>/dev/null; then
    design_capacity=$(awk -v e="$energy_design" 'BEGIN {printf "%.2f Wh", e/1000000}')
elif [ -n "$charge_design" ] && [ -n "$voltage" ]; then
    design_capacity=$(awk -v c="$charge_design" -v v="$voltage" 'BEGIN {printf "%.2f Wh", (c*v)/1000000000000}')
else
    design_capacity="N/A"
fi

time_text="Time unavailable"
if [ -n "$power" ] && [ "$power" -gt 0 ] 2>/dev/null && [ -n "$energy_now" ]; then
    if [ "$status" = "Discharging" ]; then
        minutes=$((energy_now * 60 / power))
        time_text="$((minutes / 60))h $((minutes % 60))m left"
    elif [ "$status" = "Charging" ] && [ -n "$energy_full" ]; then
        minutes=$(((energy_full - energy_now) * 60 / power))
        [ "$minutes" -lt 0 ] && minutes=0
        time_text="$((minutes / 60))h $((minutes % 60))m to full"
    fi
fi

printf '%s\n' \
    "FOUND=1" \
    "STATUS=${status:-Unknown}" \
    "CAPACITY=${capacity:-N/A}" \
    "TIME=$time_text" \
    "POWER=$power_text" \
    "VOLTAGE=$voltage_text" \
    "CURRENT=$current_text" \
    "HEALTH=$health" \
    "WEAR=$wear_text" \
    "CYCLES=${cycles:-N/A}" \
    "TECHNOLOGY=${technology:-N/A}" \
    "MODEL=${model:-N/A}" \
    "MANUFACTURER=${manufacturer:-N/A}" \
    "FULL_CAPACITY=$full_capacity" \
    "DESIGN_CAPACITY=$design_capacity"
