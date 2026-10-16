#!/usr/bin/env bash
name="${1:-}"
case "$name" in
    datepopup|weatherpopup|powermenu|dashboard|dock) ;;
    *) exit 1 ;;
esac

stamp="${XDG_RUNTIME_DIR:-/tmp}/doiz-popup-closed-$name"

pat() { printf '(qs|quickshell) .*-c %s' "$1"; }

dockconf="${XDG_DATA_HOME:-$HOME/.local/share}/doiz/dock.conf"

for other in datepopup weatherpopup powermenu dashboard dock; do
    [ "$other" = "$name" ] && continue
    if [ "$other" = dock ] && grep -qx 'keep=1' "$dockconf" 2>/dev/null && grep -qx 'mode=dock' "$dockconf" 2>/dev/null; then
        continue
    fi
    pkill -f "$(pat "$other")" >/dev/null 2>&1
done

if pgrep -f "$(pat "$name")" >/dev/null 2>&1; then
    qs -c "$name" ipc call popup close >/dev/null 2>&1 \
        || pkill -f "$(pat "$name")"
    exit 0
fi

if [ -f "$stamp" ]; then
    last=$(cat "$stamp" 2>/dev/null)
    rm -f "$stamp"
    now=$(date +%s%N)
    if [ -n "$last" ] && [ $(( (now - last) / 1000000 )) -lt 400 ]; then
        exit 0
    fi
fi

setsid -f qs -c "$name" >/dev/null 2>&1 </dev/null
