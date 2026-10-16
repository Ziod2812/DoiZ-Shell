#!/usr/bin/env bash
set -euo pipefail

DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"

windows() {
    command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || return 0

    local active
    active="$(hyprctl monitors -j 2>/dev/null | jq -c '[.[].activeWorkspace.id]')" || return 0

    hyprctl clients -j 2>/dev/null | jq -r --argjson ws "$active" '
        map(select(.mapped and (.hidden | not) and ((.workspace.id as $w | $ws | index($w)) != null)))
        | sort_by(.focusHistoryID)
        | .[]
        | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"
    ' 2>/dev/null || true
}

GEOMETRY="$(windows | slurp -w 2 -b 00000040 -c cba6f7ff -B 00000000 2>/dev/null || true)"
[ -z "$GEOMETRY" ] && exit 0

SHOT="$(mktemp --suffix=.png "${XDG_RUNTIME_DIR:-/tmp}/doiz-shot-XXXXXX")"
grim -g "$GEOMETRY" "$SHOT"

if command -v qs >/dev/null 2>&1 && [ -f "$HOME/.config/quickshell/screenshot/shell.qml" ]; then
    DOIZ_SHOT="$SHOT" DOIZ_DIR="$DIR" exec qs -c screenshot -n
fi

FILE="$DIR/area-$(date +%Y-%m-%d_%H-%M-%S).png"
mv "$SHOT" "$FILE"
wl-copy < "$FILE"
notify-send -a "DoiZ" "Screenshot saved" "$FILE"
