#!/usr/bin/env bash
export LC_ALL=C

tmpa=$(mktemp)
tmpb=$(mktemp)
trap 'rm -f "$tmpa" "$tmpb"' EXIT

has_nv=0
command -v nvidia-smi >/dev/null 2>&1 && has_nv=1

has_amd=0
for c in /sys/class/drm/card[0-9]; do
    [ -r "$c/device/gpu_busy_percent" ] && has_amd=1
done

fdsample() {
    grep -s -r -H -E '^(drm-client-id|drm-engine-[a-z0-9_-]+|drm-total-(vram|local|system)[0-9]*|drm-memory-(vram|gtt)):' /proc/[0-9]*/fdinfo 2>/dev/null | awk '
        {
            i = index($0, ":drm-")
            path = substr($0, 1, i - 1)
            rest = substr($0, i + 1)
            split(path, pp, "/")
            pid = pp[3]
            n = index(rest, ":")
            key = substr(rest, 1, n - 1)
            val = substr(rest, n + 1)
            gsub(/^[ \t]+/, "", val)
            split(val, vv, " ")
            num = vv[1] + 0
            unit = vv[2]
            if (path != lastpath) { lastpath = path; skip = 0; cid = "" }
            if (key == "drm-client-id") {
                cid = pid ":" vv[1]
                if (seen[cid]++) skip = 1
                next
            }
            if (skip || cid == "") next
            mult = 1
            if (unit == "KiB") mult = 1024
            else if (unit == "MiB") mult = 1048576
            else if (unit == "GiB") mult = 1073741824
            if (key ~ /^drm-engine-capacity/) next
            if (key ~ /^drm-engine-/) print "E", cid, key, num
            else print "M", cid, key, num * mult
        }'
}

use_fd=0
[ "$has_nv" -eq 0 ] && [ "$has_amd" -eq 0 ] && use_fd=1

[ "$use_fd" -eq 1 ] && fdsample > "$tmpa"
t1=$(date +%s%N)

read -r _ u1 n1 s1 i1 w1 q1 sq1 _ < /proc/stat
sleep 0.3
read -r _ u2 n2 s2 i2 w2 q2 sq2 _ < /proc/stat

[ "$use_fd" -eq 1 ] && fdsample > "$tmpb"
t2=$(date +%s%N)

tt1=$((u1 + n1 + s1 + i1 + w1 + q1 + sq1))
tt2=$((u2 + n2 + s2 + i2 + w2 + q2 + sq2))
dt=$((tt2 - tt1))
di=$(((i2 + w2) - (i1 + w1)))
cpu=0
[ "$dt" -gt 0 ] && cpu=$(((dt - di) * 100 / dt))

mem=$(awk '/^MemTotal/ {t=$2} /^MemAvailable/ {a=$2} END {if (t) printf "%d", (t-a)*100/t}' /proc/meminfo)
memgb=$(awk '/^MemTotal/ {t=$2} /^MemAvailable/ {a=$2} END {printf "%.1f", (t-a)/1048576}' /proc/meminfo)
memtotal_b=$(awk '/^MemTotal/ {printf "%d", $2*1024}' /proc/meminfo)

pcent() {
    df --output=pcent "$1" 2>/dev/null | tail -n1 | tr -dc '0-9'
}

rootp=$(pcent /)
bootp=$(pcent /boot)
homep=$(pcent "$HOME")

gpu=-1
vram=-1
vramgb=0

if [ "$has_nv" -eq 1 ]; then
    row=$(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | head -n1 | tr -d ' ')

    if [ -n "$row" ]; then
        gpu=$(printf '%s' "$row" | cut -d, -f1)
        vu=$(printf '%s' "$row" | cut -d, -f2)
        vt=$(printf '%s' "$row" | cut -d, -f3)

        if [ "${vt:-0}" -gt 0 ] 2>/dev/null; then
            vram=$((vu * 100 / vt))
            vramgb=$(awk -v u="$vu" 'BEGIN {printf "%.1f", u/1024}')
        fi
    fi
elif [ "$has_amd" -eq 1 ]; then
    for c in /sys/class/drm/card[0-9]; do
        d="$c/device"
        [ -r "$d/gpu_busy_percent" ] || continue

        gpu=$(cat "$d/gpu_busy_percent" 2>/dev/null)

        if [ -r "$d/mem_info_vram_used" ] && [ -r "$d/mem_info_vram_total" ]; then
            vu=$(cat "$d/mem_info_vram_used")
            vt=$(cat "$d/mem_info_vram_total")

            if [ "${vt:-0}" -gt 0 ] 2>/dev/null; then
                vram=$((vu * 100 / vt))
                vramgb=$(awk -v u="$vu" 'BEGIN {printf "%.1f", u/1073741824}')
            fi
        fi

        break
    done
else
    dtns=$((t2 - t1))

    gpu=$(awk -v dt="$dtns" '
        NR == FNR { if ($1 == "E") a[$2 " " $3] = $4; next }
        $1 == "E" {
            k = $2 " " $3
            if (k in a) {
                d = $4 - a[k]
                if (d > 0) e[$3] += d
                ok = 1
            }
        }
        END {
            if (!ok || dt <= 0) { print -1; exit }
            m = 0
            for (n in e) if (e[n] > m) m = e[n]
            u = m * 100 / dt
            if (u > 100) u = 100
            printf "%d", u + 0.5
        }' "$tmpa" "$tmpb")

    if [ "${gpu:--1}" -ge 0 ] 2>/dev/null; then
        used=$(awk '
            $1 == "M" {
                cat = ($3 ~ /vram|local/) ? "v" : "s"
                k = $2 SUBSEP cat
                if ($4 > best[k]) best[k] = $4
            }
            END {
                for (k in best) {
                    split(k, kk, SUBSEP)
                    if (kk[2] == "v") v += best[k]
                    else s += best[k]
                }
                printf "%d", (v > 0 ? v : s)
            }' "$tmpb")

        vram=$((used * 100 / memtotal_b))
        vramgb=$(awk -v u="$used" 'BEGIN {printf "%.1f", u/1073741824}')
    fi
fi

printf 'cpu=%s\nmem=%s\nmemgb=%s\nroot=%s\nboot=%s\nhome=%s\ngpu=%s\nvram=%s\nvramgb=%s\n' \
    "${cpu:-0}" "${mem:-0}" "${memgb:-0}" "${rootp:-0}" "${bootp:--1}" "${homep:-0}" "${gpu:--1}" "${vram:--1}" "${vramgb:-0}"
