#!/usr/bin/env bash
set -uo pipefail

MODE="${1:-toggle}"
DIR="$HOME/Videos/Recordings"
mkdir -p "$DIR"

if pgrep -x wf-recorder >/dev/null 2>&1; then
    pkill -INT -x wf-recorder
    notify-send -a "DoiZ" "Recording" "Stopped"
    exit 0
fi

if ! command -v wf-recorder >/dev/null 2>&1; then
    notify-send -a "DoiZ" "Recording" "wf-recorder not installed"
    exit 1
fi

FILE="$DIR/rec-$(date +%Y-%m-%d_%H-%M-%S).mp4"

case "$MODE" in
    toggle)
        wf-recorder -f "$FILE" >/dev/null 2>&1 &
        notify-send -a "DoiZ" "Recording" "Started (no audio)"
        ;;
    audio)
        wf-recorder --audio -f "$FILE" >/dev/null 2>&1 &
        notify-send -a "DoiZ" "Recording" "Started (with audio)"
        ;;
    region)
        GEOMETRY="$(slurp)"
        if [ -z "$GEOMETRY" ]; then
            exit 0
        fi
        wf-recorder -g "$GEOMETRY" -f "$FILE" >/dev/null 2>&1 &
        notify-send -a "DoiZ" "Recording" "Started (region)"
        ;;
    *)
        echo "usage: record.sh {toggle|audio|region}" >&2
        exit 1
        ;;
esac
