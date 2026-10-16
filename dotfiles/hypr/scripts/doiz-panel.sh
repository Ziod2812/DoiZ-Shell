#!/usr/bin/env bash
name="${1:-}"
panels="network brightness volume battery sysinfo"

case " $panels " in
    *" $name "*) ;;
    *) echo "usage: ${0##*/} network|brightness|volume|battery|sysinfo" >&2; exit 1 ;;
esac

for other in $panels; do
    [ "$other" = "$name" ] && continue
    qs -c "$other" ipc call "$other" hide >/dev/null 2>&1 &
done

qs -c "$name" ipc call "$name" toggle >/dev/null 2>&1 || qs -c "$name" -n >/dev/null 2>&1 &
wait
