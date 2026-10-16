#!/usr/bin/env bash
set -uo pipefail

SOCKET="${MPVPAPER_SOCKET:-${XDG_RUNTIME_DIR:-/tmp}/doiz-mpvpaper-socket}"
OLD_VIDEO="${1:-}"
NEW_VIDEO="${2:-}"
TRANSITION_TYPE="${DOIZ_VIDEO_TRANSITION:-grow}"
TRANSITION_DURATION="${DOIZ_VIDEO_TRANSITION_DURATION:-1}"

if [ -z "$NEW_VIDEO" ] || [ ! -f "$NEW_VIDEO" ]; then
    echo "usage: video-wallpaper-transition.sh <old-video-or-empty> <new-video>" >&2
    exit 1
fi

for dep in awww awww-daemon ffmpeg; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo "missing dependency: $dep" >&2
        exit 1
    fi
done

OLD_FRAME="$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/doiz-transition-old.XXXXXX.jpg")"
NEW_FRAME="$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/doiz-transition-new.XXXXXX.jpg")"
trap 'rm -f "$OLD_FRAME" "$NEW_FRAME"' EXIT

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

if ! awww query >/dev/null 2>&1; then
    awww-daemon >/dev/null 2>&1 &
    for _ in $(seq 1 30); do
        awww query >/dev/null 2>&1 && break
        sleep 0.1
    done
fi

if pgrep -x mpvpaper >/dev/null 2>&1; then
    if grab_current_frame "$OLD_FRAME"; then
        awww img "$OLD_FRAME" --transition-type none >/dev/null 2>&1 || true
        sleep 0.3
    fi

    pkill -x mpvpaper 2>/dev/null || true

    for _ in $(seq 1 30); do
        pgrep -x mpvpaper >/dev/null 2>&1 || break
        sleep 0.1
    done

    rm -f "$SOCKET"
fi

ffmpeg -y -ss 0 -i "$NEW_VIDEO" -vframes 1 -q:v 2 "$NEW_FRAME" 2>/dev/null

if [ ! -s "$NEW_FRAME" ]; then
    echo "could not extract the first frame of $NEW_VIDEO" >&2
    exit 1
fi

awww img "$NEW_FRAME" \
    --transition-type "$TRANSITION_TYPE" \
    --transition-duration "$TRANSITION_DURATION" \
    --transition-fps 60 >/dev/null 2>&1 || exit 1

sleep "$TRANSITION_DURATION"
