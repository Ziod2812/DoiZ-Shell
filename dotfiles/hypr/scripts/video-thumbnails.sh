#!/usr/bin/env bash
set -uo pipefail

DIR="${1:-}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/doiz/video-thumbs"

[ -d "$DIR" ] || exit 0

mkdir -p "$CACHE"

HAVE_FFMPEG=0
command -v ffmpeg >/dev/null 2>&1 && HAVE_FFMPEG=1

pending=()

while IFS= read -r -d '' file; do
    key="$(printf '%s\n%s' "$file" "$(stat -c %Y "$file" 2>/dev/null)" | md5sum | cut -d' ' -f1)"
    thumb="$CACHE/$key.jpg"

    if [ -s "$thumb" ]; then
        printf '%s\t%s\n' "$file" "$thumb"
    else
        pending+=("$file"$'\t'"$thumb")
    fi
done < <(
    find "$DIR" -type f \( -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.avi' \) -print0 2>/dev/null | sort -z -f
)

[ "$HAVE_FFMPEG" = 1 ] || exit 0
[ "${#pending[@]}" -gt 0 ] || exit 0

for entry in "${pending[@]}"; do
    file="${entry%%$'\t'*}"
    thumb="${entry#*$'\t'}"
    tmp="${thumb%.jpg}.tmp.jpg"

    for offset in 1 0; do
        nice -n 10 ffmpeg -y -loglevel error -ss "$offset" -i "$file" -vframes 1 -vf "scale=480:-2" -q:v 4 "$tmp" >/dev/null 2>&1
        [ -s "$tmp" ] && break
    done

    if [ -s "$tmp" ]; then
        mv -f "$tmp" "$thumb"
        printf '%s\t%s\n' "$file" "$thumb"
    else
        rm -f "$tmp"
    fi
done
