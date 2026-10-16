#!/bin/sh

os=$(. /etc/os-release 2>/dev/null && printf '%s' "${PRETTY_NAME:-$NAME}")
wm=${XDG_CURRENT_DESKTOP:-$DESKTOP_SESSION}
up=$(uptime -p 2>/dev/null)
cpu=$(sed -n 's/^model name[[:space:]]*:[[:space:]]*//p' /proc/cpuinfo | head -n1)
kernel=$(uname -r)
stat=$(head -n1 /proc/stat)

temp=""
for z in /sys/class/thermal/thermal_zone*; do
    t=$(cat "$z/type" 2>/dev/null)
    case "$t" in
        x86_pkg_temp|k10temp|coretemp|cpu*)
            temp=$(cat "$z/temp" 2>/dev/null)
            break
            ;;
    esac
done
[ -n "$temp" ] || temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)

mem=$(awk '/^MemTotal/ {t=$2} /^MemAvailable/ {a=$2} END {printf "%d %d", t, t-a}' /proc/meminfo)
memx=$(awk '/^MemAvailable/ {a=$2} /^Cached/ {c=$2} /^SwapTotal/ {st=$2} /^SwapFree/ {sf=$2} END {printf "%d %d %d %d", a, c, st, st-sf}' /proc/meminfo)

printf '%s\n' \
    "OS=${os:-Linux}" \
    "WM=${wm:-unknown}" \
    "UPTIME=$up" \
    "CPU=$cpu" \
    "KERNEL=$kernel" \
    "STAT=$stat" \
    "TEMP=$temp" \
    "MEM=$mem" \
    "MEMX=$memx"
