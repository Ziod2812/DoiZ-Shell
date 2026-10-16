#!/usr/bin/env bash
mode="${1:-next}"
LOG=/tmp/doiz-wsoverview.log
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/wsoverview"

running() { pgrep -f '(qs|quickshell) .*wsoverview' >/dev/null 2>&1; }

ipc_call() {
    local bin err
    for bin in qs quickshell; do
        command -v "$bin" >/dev/null 2>&1 || continue
        err=$("$bin" -c wsoverview ipc call wsoverview "$1" 2>&1) && return 0
        echo "$(date +%T) $bin -c: $err" >>"$LOG"
        err=$("$bin" -p "$CFG_DIR" ipc call wsoverview "$1" 2>&1) && return 0
        echo "$(date +%T) $bin -p: $err" >>"$LOG"
    done
    echo "$(date +%T) ipc $1 FAILED (moi cach deu loi)" >>"$LOG"
    return 1
}

case "$mode" in
    wheel-down|wheel-up)
        [ "$mode" = wheel-down ] && dir=next || dir=prev
        if running; then
            ipc_call "$dir"
        else
            [ "$mode" = wheel-down ] && ws='r+1' || ws='r-1'
            hyprctl dispatch "hl.dsp.focus({ workspace = \"$ws\" })" >/dev/null 2>&1
        fi
        exit 0
        ;;
esac

dir="$mode"
[ "$dir" = prev ] || dir=next

if running; then
    ipc_call "$dir"
    exit 0
fi

WT_DIR="$dir" setsid -f qs -c wsoverview >/dev/null 2>&1 </dev/null
