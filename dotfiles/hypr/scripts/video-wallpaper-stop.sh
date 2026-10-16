#!/usr/bin/env bash
set -uo pipefail

SOCKET="${MPVPAPER_SOCKET:-${XDG_RUNTIME_DIR:-/tmp}/doiz-mpvpaper-socket}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/doiz-video-wallpaper"
CURRENT_FILE="$STATE_DIR/current"

if ! pgrep -x mpvpaper >/dev/null 2>&1; then
    rm -f "$SOCKET" "$CURRENT_FILE"
    exit 0
fi

OLD_VIDEO="$(cat "$CURRENT_FILE" 2>/dev/null || echo "")"

have_all() {
    local dep
    for dep in "$@"; do
        command -v "$dep" >/dev/null 2>&1 || return 1
    done
}

grab_current_frame() {
    local out="$1" i

    [ -S "$SOCKET" ] || return 1
    command -v socat >/dev/null 2>&1 || return 1

    printf '%s\n' '{ "command": ["set_property", "pause", true] }' \
        | timeout 2 socat - "$SOCKET" >/dev/null 2>&1

    : > "$out"
    printf '{ "command": ["screenshot-to-file", "%s", "video"] }\n' "$out" \
        | timeout 3 socat - "$SOCKET" >/dev/null 2>&1

    for i in 1 2 3 4 5 6 7 8 9 10; do
        [ -s "$out" ] && return 0
        sleep 0.05
    done

    if [ -f "$OLD_VIDEO" ] && command -v jq >/dev/null 2>&1 && command -v ffmpeg >/dev/null 2>&1; then
        local t
        t="$(
            printf '%s\n' '{ "command": ["get_property", "time-pos"] }' \
                | timeout 2 socat - "$SOCKET" 2>/dev/null \
                | jq -r '.data // empty' 2>/dev/null
        )"
        if [ -n "$t" ]; then
            ffmpeg -y -ss "$t" -i "$OLD_VIDEO" -vframes 1 -q:v 2 "$out" 2>/dev/null
            [ -s "$out" ] && return 0
        fi
    fi

    return 1
}

if have_all socat awww timeout; then
    FRAME="$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/doiz-video-stop.XXXXXX.jpg")"
    trap 'rm -f "$FRAME"' EXIT

    if grab_current_frame "$FRAME"; then
        awww img "$FRAME" --transition-type none >/dev/null 2>&1 || true
        sleep 0.12
    fi
fi

pkill -x mpvpaper 2>/dev/null || true

for _ in $(seq 1 30); do
    pgrep -x mpvpaper >/dev/null 2>&1 || break
    sleep 0.1
done

rm -f "$SOCKET" "$CURRENT_FILE"
