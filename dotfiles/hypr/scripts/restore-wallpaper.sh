#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/doiz/current-wallpaper"

command -v awww >/dev/null 2>&1 || exit 0

pgrep -x mpvpaper >/dev/null 2>&1 && exit 0

for _ in $(seq 1 40); do
    awww query >/dev/null 2>&1 && break
    sleep 0.25
done

awww query >/dev/null 2>&1 || exit 1

WALLPAPER=""
[ -f "$STATE_FILE" ] && WALLPAPER="$(head -n 1 "$STATE_FILE")"

if [ -n "$WALLPAPER" ] && [ -f "$WALLPAPER" ]; then
    case "${WALLPAPER,,}" in
        *.mp4|*.webm|*.mkv|*.mov|*.avi)
            if command -v mpvpaper >/dev/null 2>&1; then
                DOIZ_VIDEO_TRANSITION=none DOIZ_VIDEO_TRANSITION_DURATION=0 \
                    bash "$SCRIPT_DIR/video-wallpaper.sh" "$WALLPAPER" && exit 0
            fi
            ;;
        *)
            awww img "$WALLPAPER" --transition-type none >/dev/null 2>&1 && exit 0
            ;;
    esac
fi

awww restore >/dev/null 2>&1 || true
