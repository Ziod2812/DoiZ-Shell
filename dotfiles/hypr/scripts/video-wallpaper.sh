#!/usr/bin/env bash
set -uo pipefail

SOCKET="${MPVPAPER_SOCKET:-${XDG_RUNTIME_DIR:-/tmp}/doiz-mpvpaper-socket}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/doiz-video-wallpaper"
CURRENT_FILE="$STATE_DIR/current"
MONITOR="${2:-*}"

NEW_VIDEO="${1:-}"

if [ -z "$NEW_VIDEO" ] || [ ! -f "$NEW_VIDEO" ]; then
    echo "usage: video-wallpaper.sh /path/to/video.mp4 [monitor]" >&2
    exit 1
fi

if ! command -v mpvpaper >/dev/null 2>&1; then
    echo "mpvpaper not found" >&2
    exit 1
fi

mkdir -p "$STATE_DIR"

player_alive() {
    local reply

    [ -S "$SOCKET" ] || return 1
    pgrep -x mpvpaper >/dev/null 2>&1 || return 1
    command -v socat >/dev/null 2>&1 || return 1

    reply="$(printf '%s\n' '{"command":["get_property","pid"]}' | timeout 2 socat - "$SOCKET" 2>/dev/null)"
    [[ "$reply" =~ \"error\"[[:space:]]*:[[:space:]]*\"success\" ]]
}

start_player() {
    pkill -x mpvpaper 2>/dev/null || true

    for _ in $(seq 1 30); do
        pgrep -x mpvpaper >/dev/null 2>&1 || break
        sleep 0.1
    done

    rm -f "$SOCKET"

    setsid mpvpaper -p -o "no-audio loop panscan=1.0 hwdec=auto-safe profile=fast framedrop=vo input-ipc-server=$SOCKET" "$MONITOR" "$NEW_VIDEO" >/dev/null 2>&1 &
}

wait_for_player() {
    for _ in $(seq 1 40); do
        player_alive && return 0
        sleep 0.1
    done

    return 1
}

OLD_VIDEO=""

if player_alive; then
    OLD_VIDEO="$(cat "$CURRENT_FILE" 2>/dev/null || echo "")"
fi

"$SCRIPT_DIR/video-wallpaper-transition.sh" "$OLD_VIDEO" "$NEW_VIDEO" || true

start_player

if wait_for_player; then
    sleep 0.3
fi

echo "$NEW_VIDEO" > "$CURRENT_FILE"

DOIZ_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/doiz"
mkdir -p "$DOIZ_STATE_DIR"
printf '%s\n' "$NEW_VIDEO" > "$DOIZ_STATE_DIR/current-wallpaper"
