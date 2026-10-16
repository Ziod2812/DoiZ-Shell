#!/bin/bash

powered() {
    bluetoothctl show 2>/dev/null | awk '/Powered:/ {print $2; exit}'
}

case "$1" in
    state)
        if [ "$(powered)" = "yes" ]; then
            echo enabled
        else
            echo disabled
        fi
        ;;
    list)
        bluetoothctl devices 2>/dev/null | while read -r _ mac name; do
            [ -n "$mac" ] || continue
            info=$(bluetoothctl info "$mac" 2>/dev/null)
            conn=$(printf '%s\n' "$info" | awk '/Connected:/ {print $2; exit}')
            paired=$(printf '%s\n' "$info" | awk '/Paired:/ {print $2; exit}')
            printf '%s|%s|%s|%s\n' "$mac" "${conn:-no}" "${paired:-no}" "$name"
        done
        ;;
    toggle)
        if [ "$(powered)" = "yes" ]; then
            bluetoothctl power off
        else
            rfkill unblock bluetooth 2>/dev/null
            bluetoothctl power on
        fi
        ;;
    connect)
        bluetoothctl connect "$2"
        ;;
    disconnect)
        bluetoothctl disconnect "$2"
        ;;
    pair)
        bluetoothctl pair "$2" && bluetoothctl trust "$2" && bluetoothctl connect "$2"
        ;;
    scan)
        bluetoothctl --timeout 10 scan on >/dev/null 2>&1
        ;;
esac
