#!/usr/bin/env bash
export LC_ALL=C.UTF-8
command -v playerctl >/dev/null 2>&1 || exit 0

player=""
fallback=""
while read -r p; do
    st=$(playerctl -p "$p" status 2>/dev/null)
    if [ "$st" = "Playing" ]; then
        player="$p"
        break
    fi
    if [ -z "$fallback" ] && [ "$st" = "Paused" ]; then
        fallback="$p"
    fi
done < <(playerctl -l 2>/dev/null)
[ -n "$player" ] || player="$fallback"
if [ -z "$player" ]; then
    case "${1:-title}" in
        title) printf 'Nothing playing\n' ;;
    esac
    exit 0
fi

case "${1:-title}" in
    toggle) playerctl -p "$player" play-pause 2>/dev/null; exit 0 ;;
    next)   playerctl -p "$player" next 2>/dev/null; exit 0 ;;
    prev)   playerctl -p "$player" previous 2>/dev/null; exit 0 ;;
    loop)
        case "$(playerctl -p "$player" loop 2>/dev/null)" in
            None)     playerctl -p "$player" loop Playlist 2>/dev/null ;;
            Playlist) playerctl -p "$player" loop Track 2>/dev/null ;;
            *)        playerctl -p "$player" loop None 2>/dev/null ;;
        esac
        exit 0
        ;;
    icon-prev) printf '\363\260\222\256\n'; exit 0 ;;
    icon-next) printf '\363\260\222\255\n'; exit 0 ;;
    icon-play)
        if [ "$(playerctl -p "$player" status 2>/dev/null)" = "Playing" ]; then
            printf '\363\260\217\244\n'
        else
            printf '\363\260\220\212\n'
        fi
        exit 0
        ;;
    icon-loop)
        case "$(playerctl -p "$player" loop 2>/dev/null)" in
            Playlist) printf '\363\260\221\226\n' ;;
            Track)    printf '\363\260\221\230\n' ;;
            *)        printf '\363\260\221\227\n' ;;
        esac
        exit 0
        ;;
    cover)
        empty="$HOME/.config/hypr/empty.png"
        square() {
            src="$1"
            dir="/tmp/doiz-lock-cover"
            mkdir -p "$dir"
            dst="$dir/sq-$(printf '%s' "$src$(stat -c %Y "$src" 2>/dev/null)" | md5sum | cut -c1-20).png"
            if [ ! -s "$dst" ]; then
                if command -v ffmpeg >/dev/null 2>&1; then
                    ffmpeg -y -loglevel error -i "$src" -vf "crop='min(iw,ih)':'min(iw,ih)',scale=256:256" -frames:v 1 "$dst" >/dev/null 2>&1 || rm -f "$dst"
                elif command -v magick >/dev/null 2>&1; then
                    magick "$src" -gravity center -crop "%[fx:min(w,h)]x%[fx:min(w,h)]+0+0" +repage -resize 256x256 "$dst" 2>/dev/null || rm -f "$dst"
                fi
            fi
            if [ -s "$dst" ]; then printf '%s\n' "$dst"; else printf '%s\n' "$src"; fi
        }
        url=$(playerctl -p "$player" metadata mpris:artUrl 2>/dev/null)
        [ -n "$url" ] || { printf '%s\n' "$empty"; exit 0; }
        case "$url" in
            file://*)
                f=${url#file://}
                f=$(printf '%b' "${f//%/\\x}")
                if [ -f "$f" ]; then square "$f"; else printf '%s\n' "$empty"; fi
                ;;
            http://*|https://*)
                dir="/tmp/doiz-lock-cover"
                mkdir -p "$dir"
                find "$dir" -type f -mtime +1 -delete 2>/dev/null
                f="$dir/$(printf '%s' "$url" | md5sum | cut -c1-20).jpg"
                if [ ! -s "$f" ]; then
                    if command -v curl >/dev/null 2>&1; then
                        curl -fsL --max-time 5 -o "$f" "$url" 2>/dev/null || rm -f "$f"
                    elif command -v wget >/dev/null 2>&1; then
                        wget -q -T 5 -O "$f" "$url" 2>/dev/null || rm -f "$f"
                    fi
                fi
                if [ -s "$f" ]; then square "$f"; else printf '%s\n' "$empty"; fi
                ;;
            *) printf '%s\n' "$empty" ;;
        esac
        exit 0
        ;;
    source)
        n=${player%%.*}
        n=${n^}
        printf '%s\n' "$n"
        exit 0
        ;;
    progress)
        pos=$(playerctl -p "$player" position 2>/dev/null)
        len=$(playerctl -p "$player" metadata mpris:length 2>/dev/null)
        pos=${pos%%.*}; pos=${pos:-0}
        len=$(( ${len:-0} / 1000000 ))
        [ "$len" -gt 0 ] || { printf '\n'; exit 0; }
        [ "$pos" -gt "$len" ] && pos=$len
        w=14
        k=$(( pos * (w - 1) / len ))
        bar=""
        for ((i=0; i<w; i++)); do
            if   [ "$i" -lt "$k" ]; then bar+="━"
            elif [ "$i" -eq "$k" ]; then bar+="●"
            else bar+="─"
            fi
        done
        printf '%5s %s %5s\n' "$(printf '%d:%02d' $((pos/60)) $((pos%60)))" "$bar" "$(printf '%d:%02d' $((len/60)) $((len%60)))"
        exit 0
        ;;
    title)  v=$(playerctl -p "$player" metadata xesam:title 2>/dev/null) ;;
    artist) v=$(playerctl -p "$player" metadata xesam:artist 2>/dev/null) ;;
    *)      exit 0 ;;
esac
[ -n "$v" ] || exit 0

v=${v//$'\n'/ }
W=26
if [ "${#v}" -gt "$W" ]; then
    v="${v:0:$((W-1))}…"
fi
while [ "${#v}" -lt "$W" ]; do v+=$'\u00a0'; done
v=${v//&/&amp;}
v=${v//</&lt;}
v=${v//>/&gt;}
case "${1:-title}" in
    title) v="<b>${v}</b>" ;;
esac

printf '%s\n' "$v"
