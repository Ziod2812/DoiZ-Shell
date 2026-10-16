#!/usr/bin/env bash
set -u

SCHEMA="org.gnome.desktop.interface"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
THEME_PY="$CONFIG_HOME/theme/scripts/apply-theme.py"
THEME_CONF="$CONFIG_HOME/theme/theme.conf"
ICON_DARK="${DOIZ_ICON_DARK:-Papirus-Dark}"
ICON_LIGHT="${DOIZ_ICON_LIGHT:-Papirus-Light}"

if ! command -v gsettings >/dev/null 2>&1; then
    echo "gsettings not found" >&2
    exit 1
fi

current() {
    local scheme
    scheme="$(gsettings get "$SCHEMA" color-scheme 2>/dev/null | tr -d "'")"

    case "$scheme" in
        prefer-light|default) echo light; return ;;
        prefer-dark) echo dark; return ;;
    esac

    if [ -f "$THEME_CONF" ]; then
        scheme="$(sed -n 's/^system_mode *= *//p' "$THEME_CONF" | head -n1 | tr -d '[:space:]')"
        [ "$scheme" = "light" ] && { echo light; return; }
    fi

    echo dark
}

theme_exists() {
    local name="$1" dir
    for dir in "$HOME/.themes" "$HOME/.local/share/themes" /usr/share/themes; do
        [ -d "$dir/$name" ] && return 0
    done
    return 1
}

icon_exists() {
    local name="$1" dir
    for dir in "$HOME/.icons" "$HOME/.local/share/icons" /usr/share/icons; do
        [ -d "$dir/$name" ] && return 0
    done
    return 1
}

pick_gtk_theme() {
    local mode="$1" cur="$2" base
    base="${cur%-dark}"
    base="${base%-Dark}"
    base="${base%:dark}"

    case "$base" in
        "") base="Adwaita" ;;
    esac

    if [ "$mode" = "dark" ]; then
        for candidate in "${base}-dark" "${base}-Dark" "$base"; do
            theme_exists "$candidate" && { echo "$candidate"; return; }
        done
        echo "$cur"
    else
        theme_exists "$base" && { echo "$base"; return; }
        echo "$cur"
    fi
}

write_gtk_ini() {
    local file="$1" prefer="$2" name="$3" tmp

    mkdir -p "$(dirname "$file")"
    [ -f "$file" ] || printf '[Settings]\n' > "$file"
    grep -q '^\[Settings\]' "$file" || printf '[Settings]\n' >> "$file"

    tmp="$(mktemp)"
    grep -v -E '^(gtk-application-prefer-dark-theme|gtk-theme-name)[[:space:]]*=' "$file" > "$tmp"
    sed -i "/^\[Settings\]/a gtk-application-prefer-dark-theme=$prefer\ngtk-theme-name=$name" "$tmp"
    cat "$tmp" > "$file"
    rm -f "$tmp"
}

write_icon_ini() {
    local file="$1" icon="$2" tmp

    mkdir -p "$(dirname "$file")"
    [ -f "$file" ] || printf '[Settings]\n' > "$file"
    grep -q '^\[Settings\]' "$file" || printf '[Settings]\n' >> "$file"

    tmp="$(mktemp)"
    grep -v -E '^gtk-icon-theme-name[[:space:]]*=' "$file" > "$tmp"
    sed -i "/^\[Settings\]/a gtk-icon-theme-name=$icon" "$tmp"
    cat "$tmp" > "$file"
    rm -f "$tmp"
}

write_qt_icon() {
    local file="$CONFIG_HOME/qt6ct/qt6ct.conf" icon="$1" tmp

    mkdir -p "$(dirname "$file")"
    [ -f "$file" ] || printf '[Appearance]\n' > "$file"
    grep -q '^\[Appearance\]' "$file" || printf '\n[Appearance]\n' >> "$file"

    tmp="$(mktemp)"
    grep -v -E '^icon_theme[[:space:]]*=' "$file" > "$tmp"
    sed -i "/^\[Appearance\]/a icon_theme=$icon" "$tmp"
    cat "$tmp" > "$file"
    rm -f "$tmp"
}

apply_icons() {
    local mode="$1" want

    if [ "$mode" = "dark" ]; then
        want="$ICON_DARK"
    else
        want="$ICON_LIGHT"
    fi

    icon_exists "$want" || return 0

    gsettings set "$SCHEMA" icon-theme "$want" 2>/dev/null || true
    write_icon_ini "$CONFIG_HOME/gtk-3.0/settings.ini" "$want"
    write_icon_ini "$CONFIG_HOME/gtk-4.0/settings.ini" "$want"
    write_qt_icon "$want"
}

apply() {
    local mode="$1" scheme prefer cur_gtk new_gtk

    if [ "$mode" = "dark" ]; then
        scheme="prefer-dark"
        prefer=1
    else
        scheme="prefer-light"
        prefer=0
    fi

    gsettings set "$SCHEMA" color-scheme "$scheme" 2>/dev/null ||
        { [ "$mode" = "light" ] && gsettings set "$SCHEMA" color-scheme default; }

    cur_gtk="$(gsettings get "$SCHEMA" gtk-theme 2>/dev/null | tr -d "'")"

    case "$cur_gtk" in
        DoiZ-Dyn-*)
            cur_gtk="$(sed -n 's/^gtk_base *= *//p' "$THEME_CONF" 2>/dev/null | head -n1 | tr -d '[:space:]')"
            ;;
    esac

    new_gtk="$(pick_gtk_theme "$mode" "$cur_gtk")"

    if [ ! -f "$THEME_PY" ] && [ -n "$new_gtk" ] && [ "$new_gtk" != "$cur_gtk" ]; then
        gsettings set "$SCHEMA" gtk-theme "$new_gtk" 2>/dev/null || true
    fi

    [ -n "$new_gtk" ] || new_gtk="$cur_gtk"
    write_gtk_ini "$CONFIG_HOME/gtk-3.0/settings.ini" "$prefer" "${new_gtk:-Adwaita}"
    write_gtk_ini "$CONFIG_HOME/gtk-4.0/settings.ini" "$prefer" "${new_gtk:-Adwaita}"

    if [ -f "$THEME_PY" ]; then
        if [ "${DOIZ_THEME_SCOPE:-system}" = "all" ]; then
            python3 "$THEME_PY" --mode "$mode" --gtk-base "$new_gtk" >/dev/null 2>&1 || true
        else
            python3 "$THEME_PY" --system "$mode" --gtk-base "$new_gtk" >/dev/null 2>&1 || true
        fi
    else
        apply_icons "$mode"
    fi
}

case "${1:-status}" in
    toggle)
        if [ "$(current)" = "dark" ]; then apply light; else apply dark; fi
        current
        ;;
    dark|light)
        apply "$1"
        current
        ;;
    icons)
        if [ ! -f "$THEME_PY" ] || ! python3 "$THEME_PY" --icons >/dev/null 2>&1; then
            apply_icons "$(current)"
        fi
        current
        ;;
    status)
        current
        ;;
    *)
        echo "usage: dark-mode.sh [status|toggle|dark|light|icons]" >&2
        exit 1
        ;;
esac
