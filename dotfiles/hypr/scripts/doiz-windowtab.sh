#!/usr/bin/env bash
dir="${1:-next}"
[ "$dir" = prev ] || dir=next

if pgrep -f '(qs|quickshell) .*-c windowtab' >/dev/null 2>&1; then
    qs -c windowtab ipc call windowtab "$dir" >/dev/null 2>&1
    exit 0
fi

WT_DIR="$dir" setsid -f qs -c windowtab >/dev/null 2>&1 </dev/null
