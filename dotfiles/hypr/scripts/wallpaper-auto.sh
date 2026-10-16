#!/usr/bin/env bash
set -uo pipefail

CFG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CONF="$CFG_HOME/mycfg/wallpaper-auto"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/doiz"
STATE_FILE="$STATE_DIR/wallpaper"
RUNTIME="${XDG_RUNTIME_DIR:-/tmp}"
SCRIPTS="$CFG_HOME/hypr/scripts"
THEME="$CFG_HOME/theme/scripts/apply-theme.py"
FRAME="$RUNTIME/doiz-video-wallpaper-theme-frame.jpg"

VIDEO_RE='\.(mp4|webm|mkv|mov|avi)$'
IMAGE_RE='\.(jpe?g|png|webp|gif)$'
TRANSITIONS=" none simple fade left right top bottom wipe wave grow center any outer random "

cfg_line() { sed -n "${1}p" "$CONF" 2>/dev/null | tr -d '[:space:]'; }

state_val() {
    sed -n "s/^$1=//p" "$STATE_FILE" 2>/dev/null | head -n 1
}

list_wallpapers() {
    local dir="$1" media="$2" re
    [ -d "$dir" ] || return 0

    case "$media" in
        image) re="$IMAGE_RE" ;;
        video) re="$VIDEO_RE" ;;
        *) re='\.(jpe?g|png|webp|gif|mp4|webm|mkv|mov|avi)$' ;;
    esac

    find "$dir" -type f -print0 2>/dev/null | sort -z -f | tr '\0' '\n' \
        | grep -Ei "$re" || true
}

apply() {
    local path="$1" transition duration

    transition="$(state_val transition)"
    duration="$(state_val duration)"
    [[ "$TRANSITIONS" == *" $transition "* ]] || transition="grow"
    [[ "$duration" =~ ^[0-9]+(\.[0-9]+)?$ ]] || duration="0.6"

    mkdir -p "$STATE_DIR"
    printf '%s\n' "$path" > "$STATE_DIR/current-wallpaper"

    if command -v awww >/dev/null 2>&1 && ! awww query >/dev/null 2>&1; then
        awww-daemon >/dev/null 2>&1 &
        sleep 0.5
    fi

    [ -f "$SCRIPTS/bar-peek" ] \
        && bash "$SCRIPTS/bar-peek" "$(awk -v d="$duration" 'BEGIN{printf "%.2f", d + 0.3}')" >/dev/null 2>&1 &

    if [[ "${path,,}" =~ $VIDEO_RE ]]; then
        DOIZ_VIDEO_TRANSITION="$transition" DOIZ_VIDEO_TRANSITION_DURATION="$duration" \
            bash "$SCRIPTS/video-wallpaper.sh" "$path" >/dev/null 2>&1 &

        if bash "$SCRIPTS/video-theme-frame.sh" "$path" "$FRAME" >/dev/null 2>&1; then
            python3 "$THEME" "$FRAME" >/dev/null 2>&1 || true
        fi
    else
        bash "$SCRIPTS/video-wallpaper-stop.sh" >/dev/null 2>&1 || true
        awww img "$path" \
            --transition-type "$transition" \
            --transition-duration "$duration" \
            --transition-step 90 \
            --transition-fps 60 >/dev/null 2>&1
        python3 "$THEME" "$path" >/dev/null 2>&1 || true
    fi
}

pick_next() {
    local dir mode media current list count idx next

    dir="$(state_val directory)"
    [ -n "$dir" ] || dir="${DOIZ_WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"

    mode="$(cfg_line 2)"
    media="$(cfg_line 4)"
    current="$(head -n 1 "$STATE_DIR/current-wallpaper" 2>/dev/null || true)"

    list="$(list_wallpapers "$dir" "$media")"
    [ -n "$list" ] || return 1
    count="$(printf '%s\n' "$list" | wc -l)"

    if [ "$mode" = "order" ]; then
        idx="$(printf '%s\n' "$list" | grep -nxF -- "$current" | head -n 1 | cut -d: -f1)"
        [ -n "$idx" ] || idx=0
        next=$(( idx % count + 1 ))
        printf '%s\n' "$list" | sed -n "${next}p"
    elif [ "$count" -gt 1 ]; then
        printf '%s\n' "$list" | grep -vxF -- "$current" | shuf -n 1
    else
        printf '%s\n' "$list"
    fi
}

do_next() {
    local path
    path="$(pick_next)" || return 1
    [ -n "$path" ] && [ -f "$path" ] || return 1
    apply "$path"
}

busy_now() {
    pgrep -f '(qs|quickshell) .*-c lockscreen' >/dev/null 2>&1 && return 0
    pgrep -f '(qs|quickshell) .*-c wallpaperpicker' >/dev/null 2>&1 && return 0
    return 1
}

daemon() {
    exec 9> "$RUNTIME/doiz-wallpaper-auto.lock"
    flock -n 9 || exit 0

    local last now minutes
    last="$(date +%s)"

    while true; do
        sleep 5
        now="$(date +%s)"

        if [ "$(cfg_line 1)" != "on" ]; then
            last="$now"
            continue
        fi

        minutes="$(cfg_line 3)"
        [[ "$minutes" =~ ^[0-9]+$ ]] && [ "$minutes" -ge 1 ] || minutes=30

        if [ $(( now - last )) -ge $(( minutes * 60 )) ]; then
            last="$now"
            busy_now || do_next
        fi
    done
}

case "${1:-daemon}" in
    daemon) daemon ;;
    next) do_next ;;
    status) printf 'on=%s mode=%s minutes=%s media=%s\n' "$(cfg_line 1)" "$(cfg_line 2)" "$(cfg_line 3)" "$(cfg_line 4)" ;;
    *) echo "usage: wallpaper-auto.sh [daemon|next|status]" >&2; exit 1 ;;
esac
