#!/usr/bin/env bash
eth=""
for d in /sys/class/net/*; do
    n="${d##*/}"
    [ -e "$d/device" ] || continue
    [ "$(cat "$d/operstate" 2>/dev/null)" = "up" ] || continue
    if [ -d "$d/wireless" ]; then
        essid="$(iwctl station "$n" show 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' \
            | awk '/Connected network/ { $1 = ""; $2 = ""; sub(/^ +/, ""); print; exit }')"
        [ -n "$essid" ] || essid="$(iw dev "$n" link 2>/dev/null | awk -F': ' '/SSID/ { print $2; exit }')"
        [ -n "$essid" ] || essid="$(nmcli -g GENERAL.CONNECTION device show "$n" 2>/dev/null)"
        echo "wifi|$essid"
        exit 0
    fi
    eth="$n"
done
[ -n "$eth" ] && echo "ethernet|" || echo "down|"
