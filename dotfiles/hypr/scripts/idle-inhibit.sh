#!/usr/bin/env bash
set -uo pipefail

PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/doiz-idle-inhibit.pid"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    kill "$(cat "$PIDFILE")" 2>/dev/null
    rm -f "$PIDFILE"
    pkill -x hypridle 2>/dev/null || true
    hypridle &
    notify-send -a "DoiZ" "Idle inhibit" "Disabled"
    exit 0
fi

pkill -x hypridle 2>/dev/null || true
systemd-inhibit --what=idle:sleep --who="DoiZ" --why="manual inhibit" --mode=block sleep infinity &
echo $! > "$PIDFILE"
notify-send -a "DoiZ" "Idle inhibit" "Enabled"
