#!/bin/sh

cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
tab="$(printf '\t')"

dirs="hypr hypr/config mycfg theme kitty fish btop cava rofi wlogout mako dunst fastfetch gtk-3.0 gtk-4.0 nvim"

files() {
    for d in $dirs; do
        for f in "$cfg/$d"/*; do
            [ -f "$f" ] || continue
            n="${f##*/}"
            case "$n" in
                *.lua|*.conf|*.jsonc|*.json|*.rasi|*.fish|*.css|*.toml|*.yml|*.yaml|*.ini|*.theme|*.env|*.template|config|config.*)
                    printf '%s\t%s\t%s\tfile\n' "$n" "$f" "${f%/*}"
                    ;;
            esac
        done
    done
}

folders() {
    for d in "$cfg"/quickshell/*/; do
        [ -d "$d" ] || continue
        p="${d%/}"
        printf 'quickshell/%s\t%s\t%s\tdir\n' "${p##*/}" "$p" "$p"
    done
}

files | sort -t "$tab" -k3,3 -k1,1 -u
folders | sort -t "$tab" -k1,1
