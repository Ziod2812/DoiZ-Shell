#!/usr/bin/env bash
set -uo pipefail

VIDEO="${1:-}"
OUT="${2:-}"

[ -f "$VIDEO" ] && [ -n "$OUT" ] || exit 1

grab() {
    rm -f "$OUT"
    ffmpeg -y -loglevel error -ss "$1" -i "$VIDEO" -vframes 1 -q:v 2 "$OUT" >/dev/null 2>&1
    [ -s "$OUT" ]
}

grab 0 || grab 1
