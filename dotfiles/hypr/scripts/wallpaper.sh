#!/usr/bin/env bash
set -euo pipefail

WALLPAPER="${1:-}"

if [ -z "$WALLPAPER" ] || [ ! -f "$WALLPAPER" ]; then
    echo "usage: wallpaper.sh /path/to/image" >&2
    exit 1
fi

WPCTL="awww"
WPDAEMON="awww-daemon"
if ! command -v "$WPCTL" >/dev/null 2>&1 || ! command -v "$WPDAEMON" >/dev/null 2>&1; then
    echo "awww and awww-daemon are required" >&2
    exit 1
fi

if ! "$WPCTL" query >/dev/null 2>&1; then
    "$WPDAEMON" &
    sleep 0.5
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
"$SCRIPT_DIR/video-wallpaper-stop.sh" || true

"$WPCTL" img "$WALLPAPER" \
    --transition-type grow \
    --transition-duration 1 \
    --transition-fps 60

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/doiz"
mkdir -p "$STATE_DIR"
printf '%s\n' "$(readlink -f "$WALLPAPER")" > "$STATE_DIR/current-wallpaper"

THEME_PY="${XDG_CONFIG_HOME:-$HOME/.config}/theme/scripts/apply-theme.py"
if [ -f "$THEME_PY" ]; then
    THEME_LOG="$STATE_DIR/apply-theme.log"
    {
        echo "== $(date '+%F %T') $(readlink -f "$WALLPAPER")"
        python3 "$THEME_PY" "$(readlink -f "$WALLPAPER")" 2>&1
    } >> "$THEME_LOG" 2>&1 || true
fi
