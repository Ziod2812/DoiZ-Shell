#!/usr/bin/env bash
pat='(qs|quickshell) .*-c wallpaperpicker'

if pgrep -f "$pat" >/dev/null 2>&1; then
    if qs -c wallpaperpicker ipc call wallpaperpicker close >/dev/null 2>&1; then
        exit 0
    fi
    pkill -f "$pat"
    exit 0
fi

setsid -f qs -c wallpaperpicker >/dev/null 2>&1 </dev/null
