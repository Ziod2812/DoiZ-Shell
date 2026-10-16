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

mem=$(awk '/^MemTotal/ {t=$2} /^MemAvailable/ {a=$2} END {if (t > 0) printf "%d", (t - a) * 100 / t; else print 0}' /proc/meminfo)
disk=$(df --output=pcent / 2>/dev/null | tail -n 1 | tr -dc '0-9')

bat=""
batstate=""
for d in /sys/class/power_supply/BAT*; do
    if [ -r "$d/capacity" ]; then
        bat=$(cat "$d/capacity" 2>/dev/null)
        batstate=$(cat "$d/status" 2>/dev/null)
        break
    fi
done

wifi=""
if command -v nmcli >/dev/null 2>&1; then
    wifi=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '$1 == "yes" {print $2; exit}')
fi

vol=""
if command -v wpctl >/dev/null 2>&1; then
    vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{printf "%d", $2 * 100}')
fi

up=$(awk '{printf "%d", $1}' /proc/uptime)

printf 'cpu=%s\nmem=%s\ndisk=%s\nbat=%s\nbatstate=%s\nwifi=%s\nvol=%s\nup=%s\n' \
    "$cpu" "$mem" "${disk:-0}" "$bat" "$batstate" "$wifi" "$vol" "$up"
