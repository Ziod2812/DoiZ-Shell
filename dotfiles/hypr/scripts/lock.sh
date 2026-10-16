#!/usr/bin/env bash
set -uo pipefail

PIDF="${XDG_RUNTIME_DIR:-/tmp}/doiz-lock.pid"
if [ "${1:-}" != "--bg" ] && [ -r "$PIDF" ]; then
    LPID="$(cat "$PIDF" 2>/dev/null)"
    if [ -n "$LPID" ] && tr '\0' ' ' < "/proc/$LPID/cmdline" 2>/dev/null | grep -q -- '-c lockscreen'; then
        exit 0
    fi
fi

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/doiz/current-wallpaper"
OUT_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/doiz"
OUT="$OUT_DIR/lock-bg.jpg"
mkdir -p "$OUT_DIR"

WP=""
[ -f "$STATE_FILE" ] && WP="$(head -n 1 "$STATE_FILE")"

if [ -n "$WP" ] && [ -f "$WP" ]; then
    case "${WP,,}" in
        *.mp4|*.webm|*.mkv|*.mov|*.avi)
            timeout 3 ffmpeg -y -loglevel error -ss 1 -i "$WP" -vframes 1 -q:v 2 "$OUT" >/dev/null 2>&1 \
                || timeout 3 ffmpeg -y -loglevel error -i "$WP" -vframes 1 -q:v 2 "$OUT" >/dev/null 2>&1 \
                || rm -f "$OUT"
            ;;
        *.gif)
            timeout 3 ffmpeg -y -loglevel error -i "$WP" -vframes 1 -q:v 2 "$OUT" >/dev/null 2>&1 || rm -f "$OUT"
            ;;
        *)
            cp -f "$WP" "$OUT" 2>/dev/null || rm -f "$OUT"
            ;;
    esac
else
    rm -f "$OUT"
fi

THEME_PY="${XDG_CONFIG_HOME:-$HOME/.config}/theme/scripts/apply-theme.py"
MARK="$OUT_DIR/lock-theme-src"
sync_theme() {
    if [ -f "$OUT" ] && [ -f "$THEME_PY" ]; then
        KEY="$WP|$(stat -c %Y "$WP" 2>/dev/null)"
        if [ "$(cat "$MARK" 2>/dev/null)" != "$KEY" ]; then
            timeout 20 python3 "$THEME_PY" "$OUT" >/dev/null 2>&1 && printf '%s\n' "$KEY" > "$MARK"
        fi
    fi
}

if [ "${1:-}" = "--bg" ]; then
    sync_theme
    exit 0
fi

QS_LOCK="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/lockscreen/shell.qml"
if ! command -v qs >/dev/null 2>&1 || [ ! -f "$QS_LOCK" ]; then
    notify-send -u critical "Lock screen" "quickshell (qs) or lockscreen/shell.qml is missing" 2>/dev/null
    exit 1
fi
sync_theme >/dev/null 2>&1 &
printf '%s\n' "$$" > "$PIDF"
exec qs -c lockscreen >/dev/null 2>&1
