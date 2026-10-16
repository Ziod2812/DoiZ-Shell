#!/bin/sh

case "$1" in
    sinks)
        wpctl status 2>/dev/null | LC_ALL=C sed 's/[^ -~]/ /g' | awk '
            /Sinks:/ { s = 1; next }
            s && /^[[:space:]]*[A-Za-z][A-Za-z ]*:[[:space:]]*$/ { exit }
            s && /^[[:space:]]*\*?[[:space:]]*[0-9]+\./ {
                line = $0
                def = (line ~ /^[[:space:]]*\*/) ? 1 : 0
                sub(/^[[:space:]]*\*?[[:space:]]*/, "", line)
                id = line
                sub(/\..*$/, "", id)
                name = line
                sub(/^[0-9]+\.[[:space:]]*/, "", name)
                sub(/[[:space:]]*\[vol:.*$/, "", name)
                printf "%s\t%s\t%d\n", id, name, def
            }
        '
        ;;
esac
