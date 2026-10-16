#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${SUDO_USER:-${USER}}"

if [ "$(id -u)" -eq 0 ] && [ -z "${SUDO_USER:-}" ]; then
    TARGET_USER="$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 && $7 !~ /(nologin|false)$/ {print $1; exit}')"
fi

if [ -z "$TARGET_USER" ] || ! id "$TARGET_USER" >/dev/null 2>&1; then
    printf '%s\n' 'Could not determine the target user.' >&2
    exit 1
fi

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
if [ -z "$TARGET_HOME" ] || [ ! -d "$TARGET_HOME" ]; then
    printf '%s\n' 'Could not determine the target home directory.' >&2
    exit 1
fi

TARGET_UID="$(id -u "$TARGET_USER")"
SESSION_RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$TARGET_UID}"
SESSION_WAYLAND="${WAYLAND_DISPLAY:-}"
SESSION_HYPRLAND="${HYPRLAND_INSTANCE_SIGNATURE:-}"

if [ -z "$SESSION_WAYLAND" ] && [ -d "$SESSION_RUNTIME" ]; then
    SESSION_WAYLAND="$(find "$SESSION_RUNTIME" -maxdepth 1 -type s -name 'wayland-*' -printf '%f\n' 2>/dev/null | head -n1)"
fi

if [ -z "$SESSION_HYPRLAND" ] && [ -d "$SESSION_RUNTIME/hypr" ]; then
    SESSION_HYPRLAND="$(find "$SESSION_RUNTIME/hypr" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | head -n1)"
fi

run_session() {
    if [ ! -d "$SESSION_RUNTIME" ] || [ -z "$SESSION_WAYLAND" ]; then
        return 1
    fi
    if [ "$(id -u)" -eq "$TARGET_UID" ]; then
        env HOME="$TARGET_HOME" XDG_CONFIG_HOME="$TARGET_HOME/.config" XDG_RUNTIME_DIR="$SESSION_RUNTIME" WAYLAND_DISPLAY="$SESSION_WAYLAND" HYPRLAND_INSTANCE_SIGNATURE="$SESSION_HYPRLAND" DBUS_SESSION_BUS_ADDRESS="unix:path=$SESSION_RUNTIME/bus" "$@"
    else
        runuser -u "$TARGET_USER" -- env HOME="$TARGET_HOME" XDG_CONFIG_HOME="$TARGET_HOME/.config" XDG_RUNTIME_DIR="$SESSION_RUNTIME" WAYLAND_DISPLAY="$SESSION_WAYLAND" HYPRLAND_INSTANCE_SIGNATURE="$SESSION_HYPRLAND" DBUS_SESSION_BUS_ADDRESS="unix:path=$SESSION_RUNTIME/bus" PATH="${PATH:-/usr/local/sbin:/usr/local/bin:/usr/bin:/bin}" "$@"
    fi
}

run_user() {
    if [ "$(id -u)" -eq 0 ]; then
        runuser -u "$TARGET_USER" -- env HOME="$TARGET_HOME" XDG_CONFIG_HOME="$TARGET_HOME/.config" PATH="${PATH:-/usr/local/sbin:/usr/local/bin:/usr/bin:/bin}" "$@"
    else
        "$@"
    fi
}

as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

if [ "$(id -u)" -ne 0 ] && ! command -v sudo >/dev/null 2>&1; then
    printf '%s\n' 'sudo is required when install.sh is not run as root.' >&2
    exit 1
fi

if [ ! -f /etc/arch-release ]; then
    printf '%s\n' 'DoiZ install.sh supports Arch Linux and Arch-based systems only.' >&2
    exit 1
fi

mapfile -t ARCH_PACKAGES < <(grep -Ev '^[[:space:]]*(#|$)' "$ROOT_DIR/packages/arch.txt")
mapfile -t AUR_PACKAGES < <(grep -Ev '^[[:space:]]*(#|$)' "$ROOT_DIR/packages/aur.txt")

printf '%s\n' '==> Syncing Arch packages'
as_root pacman -Syu --needed --noconfirm "${ARCH_PACKAGES[@]}"

printf '%s\n' '==> Installing the Mesa GPU driver for the Black Hole effect'
GPU_VENDORS=""
for f in /sys/class/drm/card[0-9]*/device/vendor; do
    [ -r "$f" ] || continue
    GPU_VENDORS="$GPU_VENDORS $(cat "$f")"
done
MESA_EXTRA=()
case "$GPU_VENDORS" in *0x1002*) MESA_EXTRA+=(vulkan-radeon) ;; esac
case "$GPU_VENDORS" in *0x8086*) MESA_EXTRA+=(vulkan-intel) ;; esac
case "$GPU_VENDORS" in *0x1af4*|*0x15ad*) MESA_EXTRA+=(vulkan-virtio) ;; esac
if [ "${#MESA_EXTRA[@]}" -gt 0 ]; then
    as_root pacman -S --needed --noconfirm "${MESA_EXTRA[@]}"
fi
case "$GPU_VENDORS" in *0x10de*)
    printf '%s\n' 'Note: NVIDIA GPU found. Mesa (nouveau/NVK) is installed; for the proprietary driver install nvidia-open + nvidia-utils yourself.' >&2
    ;;
esac

if ! command -v yay >/dev/null 2>&1; then
    printf '%s\n' '==> Installing yay'
    YAY_DIR="$TARGET_HOME/.cache/doiz-yay"
    run_user mkdir -p "$TARGET_HOME/.cache"
    run_user rm -rf "$YAY_DIR"
    run_user git clone https://aur.archlinux.org/yay.git "$YAY_DIR"
    run_user bash -c "cd \"$YAY_DIR\" && makepkg -si --noconfirm"
    run_user rm -rf "$YAY_DIR"
fi

if command -v helium-browser >/dev/null 2>&1 || pacman -Qq helium-browser-bin >/dev/null 2>&1; then
    printf '%s\n' '==> Helium browser already installed, skipping'
else
    printf '%s\n' '==> Installing Helium browser'
    run_user yay -S --needed --noconfirm helium-browser-bin
fi

if ! ls "$TARGET_HOME"/.local/share/icons/hicolor/*/apps/helium.* /usr/share/icons/hicolor/*/apps/helium.* >/dev/null 2>&1; then
    HELIUM_ICON="$(find /usr/share/pixmaps /usr/share/helium* /opt/helium* -iname '*helium*.png' -o -iname '*product_logo*.png' 2>/dev/null | sort -V | tail -n 1 || true)"
    if [ -n "$HELIUM_ICON" ]; then
        printf '%s\n' "==> Registering Helium icon from $HELIUM_ICON"
        run_user mkdir -p "$TARGET_HOME/.local/share/icons/hicolor/256x256/apps"
        run_user cp "$HELIUM_ICON" "$TARGET_HOME/.local/share/icons/hicolor/256x256/apps/helium.png"
        run_user gtk-update-icon-cache -f -t "$TARGET_HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
    fi
fi

if [ "${#AUR_PACKAGES[@]}" -gt 0 ]; then
    printf '%s\n' '==> Syncing AUR packages'
    run_user yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"
fi

printf '%s\n' '==> Installing DoiZ configuration'
run_user mkdir -p "$TARGET_HOME/.config"

BACKUP_DIR="$TARGET_HOME/DoiZ-backup/date-$(date +%Y-%m-%d)_time-$(date +%H-%M-%S)"
MERGE_DIRS=" xdg-desktop-portal gtk-3.0 "

for path in "$ROOT_DIR/dotfiles"/*; do
    [ -e "$path" ] || continue
    name="$(basename "$path")"
    if [[ "$MERGE_DIRS" == *" $name "* ]] && [ -d "$path" ]; then
        while IFS= read -r -d '' src; do
            rel="${src#"$path"/}"
            dest="$TARGET_HOME/.config/$name/$rel"
            if [ -e "$dest" ] && ! cmp -s "$src" "$dest"; then
                run_user mkdir -p "$BACKUP_DIR/$name/$(dirname "$rel")"
                mv "$dest" "$BACKUP_DIR/$name/$rel"
                BACKED_UP=1
            fi
            run_user mkdir -p "$(dirname "$dest")"
            cp -a "$src" "$dest"
        done < <(find "$path" -type f -print0)
        continue
    fi
    if [ -e "$TARGET_HOME/.config/$name" ]; then
        run_user mkdir -p "$BACKUP_DIR"
        mv "$TARGET_HOME/.config/$name" "$BACKUP_DIR/$name"
        BACKED_UP=1
    fi
    cp -a "$path" "$TARGET_HOME/.config/$name"
done

if [ "${BACKED_UP:-0}" -eq 1 ]; then
    printf '%s\n' "Old configs backed up to: $BACKUP_DIR"
fi

chown -R "$TARGET_USER":"$(id -gn "$TARGET_USER")" "$TARGET_HOME/.config"

printf '%s\n' '==> Installing DoiZ executables'
find "$TARGET_HOME/.config/hypr/scripts" "$TARGET_HOME/.config/theme/scripts" "$TARGET_HOME/.config/quickshell/bar" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.py' \) -exec chmod +x {} +
chmod +x "$TARGET_HOME/.config/hypr/scripts/doiz-controlcenter" "$TARGET_HOME/.config/hypr/scripts/doiz-session" "$TARGET_HOME/.config/hypr/scripts/doiz-idle" "$TARGET_HOME/.config/hypr/scripts/doiz-notifd" "$TARGET_HOME/.config/hypr/scripts/toggle-infinite-desktop" "$TARGET_HOME/.config/hypr/scripts/toggle-auto-arrange-grid" "$TARGET_HOME/.config/hypr/scripts/blackhole" "$TARGET_HOME/.config/hypr/scripts/doiz-mediapopup" "$TARGET_HOME/.config/hypr/scripts/doiz-bar" "$TARGET_HOME/.config/hypr/scripts/doiz-cavadesk"
rm -rf "$TARGET_HOME/.config/quickshell/spidertrail" "$TARGET_HOME/.config/hypr/scripts/toggle-spidertrail" "$TARGET_HOME/.config/hypr/scripts/toggle-terminal-trail" "$TARGET_HOME/.config/kitty/cursor-trail.conf" "$TARGET_HOME/.local/state/doiz/spidertrail-on" "$TARGET_HOME/.local/state/doiz/term-trail-kitty"

if [ ! -f "$TARGET_HOME/.config/qt6ct/qt6ct.conf" ]; then
    run_user python3 "$TARGET_HOME/.config/theme/scripts/apply-theme.py" --system dark >/dev/null 2>&1 || true
    run_session "$TARGET_HOME/.config/hypr/scripts/dark-mode.sh" dark >/dev/null 2>&1 || true
fi

printf '%s\n' '==> Applying the Papirus icon theme'
run_session "$TARGET_HOME/.config/hypr/scripts/dark-mode.sh" icons >/dev/null 2>&1 || run_user "$TARGET_HOME/.config/hypr/scripts/dark-mode.sh" icons >/dev/null 2>&1 || true

printf '%s\n' '==> Setting up Thunar Places and New Document templates'
run_user bash -c '
    set -eu
    home="$1" root="$2"
    command -v xdg-user-dirs-update >/dev/null 2>&1 && xdg-user-dirs-update >/dev/null 2>&1 || true
    ud() { xdg-user-dir "$1" 2>/dev/null || true; }
    dl="$(ud DOWNLOAD)"; docs="$(ud DOCUMENTS)"; pics="$(ud PICTURES)"; vids="$(ud VIDEOS)"; mus="$(ud MUSIC)"; tpl="$(ud TEMPLATES)"
    [ -n "$dl" ] && [ "$dl" != "$home" ] || dl="$home/Downloads"
    [ -n "$docs" ] && [ "$docs" != "$home" ] || docs="$home/Documents"
    [ -n "$pics" ] && [ "$pics" != "$home" ] || pics="$home/Pictures"
    [ -n "$vids" ] && [ "$vids" != "$home" ] || vids="$home/Videos"
    [ -n "$mus" ] && [ "$mus" != "$home" ] || mus="$home/Music"
    if [ -z "$tpl" ] || [ "$tpl" = "$home" ]; then
        tpl="$home/Templates"
        command -v xdg-user-dirs-update >/dev/null 2>&1 && xdg-user-dirs-update --set TEMPLATES "$tpl" >/dev/null 2>&1 || true
    fi
    mkdir -p "$dl" "$docs" "$pics" "$vids" "$mus" "$tpl" "$pics/Wallpapers"
    for f in "$root"/assets/templates/*; do
        [ -f "$f" ] || continue
        [ -e "$tpl/$(basename "$f")" ] || cp "$f" "$tpl/"
    done
    bm="$home/.config/gtk-3.0/bookmarks"
    mkdir -p "$(dirname "$bm")"
    touch "$bm"
    for d in "$dl" "$docs" "$pics" "$vids" "$mus" "$pics/Wallpapers" "$home/.config"; do
        uri="file://$d"
        grep -qxF "$uri" "$bm" || grep -q "^$uri " "$bm" || printf "%s\n" "$uri" >> "$bm"
    done
' _ "$TARGET_HOME" "$ROOT_DIR" || true

if command -v xfconf-query >/dev/null 2>&1; then
    thumb_mode="$(run_session xfconf-query -c thunar -p /misc-thumbnail-mode 2>/dev/null || true)"
    case "$thumb_mode" in
        ''|THUNAR_THUMBNAIL_MODE_NEVER)
            printf '%s\n' '==> Enabling Thunar thumbnails'
            run_session xfconf-query -c thunar -p /misc-thumbnail-mode -n -t string -s THUNAR_THUMBNAIL_MODE_ONLY_LOCAL >/dev/null 2>&1 || true
            ;;
    esac
fi

printf '%s\n' '==> Registering the framed image/video/music thumbnailer'
run_user bash -c '
    set -eu
    home="$1"
    dir="${XDG_DATA_HOME:-$home/.local/share}/thumbnailers"
    file="$dir/doiz-image-frame.thumbnailer"
    tmp="$file.tmp.$$"
    mkdir -p "$dir"
    {
        printf "%s\n" "[Thumbnailer Entry]" "TryExec=python3"
        printf "Exec=python3 %s/.config/hypr/scripts/doiz-thumbnailer.py %%i %%o %%s\n" "$home"
        printf "%s\n" "MimeType=image/png;image/jpeg;image/webp;image/gif;image/bmp;image/tiff;video/mp4;video/webm;video/x-matroska;video/quicktime;video/x-msvideo;video/x-m4v;video/mpeg;video/ogg;audio/mpeg;audio/flac;audio/x-flac;audio/ogg;audio/x-vorbis+ogg;audio/x-opus+ogg;audio/opus;audio/mp4;audio/x-m4a;audio/aac;audio/x-wav;audio/x-ms-wma;audio/x-aiff;audio/webm;audio/x-matroska;" "" "[X-Tumbler Settings]" "Priority=1000"
    } > "$tmp"
    if ! cmp -s "$tmp" "$file" 2>/dev/null; then
        mv -f "$tmp" "$file"
        cache="${XDG_CACHE_HOME:-$home/.cache}/thumbnails"
        for size in normal large x-large xx-large; do rm -rf "$cache/$size"; done
    else
        rm -f "$tmp"
    fi
' _ "$TARGET_HOME" || true

printf '%s\n' '==> Installing and applying the DoiZ-Cursor theme'
CURSOR_THEME="DoiZ-Cursor"
if [ -d "$TARGET_HOME/.config/cursor/$CURSOR_THEME" ]; then
    run_user mkdir -p "$TARGET_HOME/.local/share/icons"
    run_user rm -rf "$TARGET_HOME/.local/share/icons/$CURSOR_THEME"
    run_user cp -a "$TARGET_HOME/.config/cursor/$CURSOR_THEME" "$TARGET_HOME/.local/share/icons/$CURSOR_THEME"
fi
CURSOR_SIZE=24
CURSOR_OK=0
for dir in /usr/share/icons "$TARGET_HOME/.local/share/icons" "$TARGET_HOME/.icons"; do
    if [ -f "$dir/$CURSOR_THEME/index.theme" ]; then
        CURSOR_OK=1
        break
    fi
done
if [ "$CURSOR_OK" -eq 1 ]; then
    run_user bash -c '
        set -eu
        home="$1" theme="$2" size="$3"
        set_ini_key() {
            local file="$1" key="$2" value="$3" tmp
            mkdir -p "$(dirname "$file")"
            [ -f "$file" ] || printf "[Settings]\n" > "$file"
            grep -q "^\[Settings\]" "$file" || printf "[Settings]\n" >> "$file"
            tmp="$(mktemp "$file.XXXXXX")"
            grep -v -E "^${key}[[:space:]]*=" "$file" > "$tmp" || true
            sed -i "/^\[Settings\]/a ${key}=${value}" "$tmp"
            chmod 644 "$tmp"
            mv -f "$tmp" "$file"
        }
        for gtk in gtk-3.0 gtk-4.0; do
            set_ini_key "$home/.config/$gtk/settings.ini" gtk-cursor-theme-name "$theme"
            set_ini_key "$home/.config/$gtk/settings.ini" gtk-cursor-theme-size "$size"
        done
        default_dir="$home/.local/share/icons/default"
        mkdir -p "$default_dir"
        tmp="$(mktemp "$default_dir/index.theme.XXXXXX")"
        printf "[Icon Theme]\nInherits=%s\n" "$theme" > "$tmp"
        chmod 644 "$tmp"
        mv -f "$tmp" "$default_dir/index.theme"
    ' _ "$TARGET_HOME" "$CURSOR_THEME" "$CURSOR_SIZE" || printf '%s\n' 'Warning: could not write the cursor settings files.' >&2
    run_session gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME" >/dev/null 2>&1 || true
    run_session gsettings set org.gnome.desktop.interface cursor-size "$CURSOR_SIZE" >/dev/null 2>&1 || true
else
    printf '%s\n' "Warning: $CURSOR_THEME was not installed; run ~/.config/cursor/build.py --install to build it." >&2
fi

printf '%s\n' '==> Installing Infinite Desktop v2 dependencies'
as_root pacman -S --needed --noconfirm python python-evdev bash jq curl tar

printf '%s\n' '==> Configuring input-group access for Infinite Desktop v2'
if ! id -nG "$TARGET_USER" | tr ' ' '\n' | grep -qx input; then
    as_root usermod -aG input "$TARGET_USER"
    printf '%s\n' 'Warning: added user to input group; log out/reboot before python-evdev can access input devices.' >&2
fi

printf '%s\n' '==> Installing Infinite Desktop v2 scripts'
INFINITE_DIR="$TARGET_HOME/.config/hypr/scripts/infinite-desktop"
INFINITE_FILES="infinite_desktop_core.py floating_tile_toggle.py navigate_windows.py resize_window.py move_window_tiled.py move_window.py hypr_ipc.py"
run_user mkdir -p "$INFINITE_DIR"
missing=0
for file in $INFINITE_FILES; do
    [ -f "$INFINITE_DIR/$file" ] || missing=1
done
if [ "$missing" = 1 ]; then
    printf '%s\n' 'Bundled Infinite Desktop scripts not found, downloading from GitHub'
    INFINITE_TMP="$TARGET_HOME/.cache/doiz-infinite-desktop"
    run_user rm -rf "$INFINITE_TMP"
    run_user mkdir -p "$INFINITE_TMP"
    run_user bash -c 'curl -fsSL https://codeload.github.com/sarodscommits/hyprland-infinitie-desktop-v2/tar.gz/refs/heads/main | tar -xz --strip-components=2 -C "$1" hyprland-infinitie-desktop-v2-main/scripts' _ "$INFINITE_TMP"
    for file in $INFINITE_FILES; do
        cp -f "$INFINITE_TMP/$file" "$INFINITE_DIR/$file"
    done
    rm -rf "$INFINITE_TMP"
fi
chown -R "$TARGET_USER":"$(id -gn "$TARGET_USER")" "$TARGET_HOME/.config/hypr/scripts/infinite-desktop"
chmod +x "$TARGET_HOME/.config/hypr/scripts/infinite-desktop/"*.py

printf '%s\n' '==> Installing SDDM video theme'
as_root rm -rf /usr/share/sddm/themes/doiz
as_root install -d /usr/share/sddm/themes
as_root cp -r "$ROOT_DIR/sddm/doiz" /usr/share/sddm/themes/doiz
as_root chmod -R a+rX /usr/share/sddm/themes/doiz
if ! grep -qx 'QtVersion=6' /usr/share/sddm/themes/doiz/metadata.desktop; then
    printf '%s\n' 'WARNING: /usr/share/sddm/themes/doiz/metadata.desktop has no "QtVersion=6" line' >&2
fi
if [ ! -x /usr/bin/sddm-greeter-qt6 ]; then
    printf '%s\n' 'WARNING: /usr/bin/sddm-greeter-qt6 not found: the SDDM theme needs a Qt6 build of sddm (0.21 or newer)' >&2
fi
as_root install -d /etc/sddm.conf.d
printf '[Theme]\nCurrent=doiz\n' | as_root tee /etc/sddm.conf.d/10-doiz-theme.conf >/dev/null
if command -v setfacl >/dev/null 2>&1; then
    as_root setfacl -m u:sddm:x "$TARGET_HOME" || true
    [ -f "$TARGET_HOME/.face" ] && as_root setfacl -m u:sddm:r "$TARGET_HOME/.face" || true
fi

printf '%s\n' '==> Enabling system services'
as_root systemctl enable NetworkManager.service
as_root systemctl enable bluetooth.service
as_root systemctl enable sddm.service

printf '%s\n' '==> Configuring fish'
if command -v fish >/dev/null 2>&1; then
    FISH_PATH="$(command -v fish)"
    CURRENT_SHELL="$(getent passwd "$TARGET_USER" | cut -d: -f7)"
    if [ "$CURRENT_SHELL" != "$FISH_PATH" ]; then
        as_root chsh -s "$FISH_PATH" "$TARGET_USER"
    fi
fi

printf '%s\n' '==> Refreshing font cache'
run_user fc-cache -f "$TARGET_HOME/.local/share/fonts" "$TARGET_HOME/.config" >/dev/null 2>&1 || true

printf '%s\n' '==> Syncing theme colors with the current wallpaper'
SYNC_SOURCE=""
STATE_WALLPAPER="$TARGET_HOME/.local/state/doiz/current-wallpaper"
if [ -f "$STATE_WALLPAPER" ]; then
    SYNC_SOURCE="$(head -n 1 "$STATE_WALLPAPER")"
fi
if [ -z "$SYNC_SOURCE" ] || [ ! -f "$SYNC_SOURCE" ]; then
    SYNC_SOURCE="$(run_session awww query 2>/dev/null | sed -n 's/.*currently displaying: image: //p' | head -n1 || true)"
fi
case "${SYNC_SOURCE,,}" in
    *.mp4|*.webm|*.mkv|*.mov|*.avi)
        SYNC_FRAME="$TARGET_HOME/.cache/doiz/install-wallpaper-frame.png"
        run_user mkdir -p "$TARGET_HOME/.cache/doiz"
        run_user rm -f "$SYNC_FRAME"
        run_user ffmpeg -y -loglevel error -ss 1 -i "$SYNC_SOURCE" -frames:v 1 "$SYNC_FRAME" >/dev/null 2>&1 \
            || run_user ffmpeg -y -loglevel error -i "$SYNC_SOURCE" -frames:v 1 "$SYNC_FRAME" >/dev/null 2>&1 \
            || true
        if [ -s "$SYNC_FRAME" ]; then
            SYNC_SOURCE="$SYNC_FRAME"
        else
            SYNC_SOURCE=""
        fi
        ;;
esac
if [ -n "$SYNC_SOURCE" ] && [ -f "$SYNC_SOURCE" ]; then
    if run_session python3 "$TARGET_HOME/.config/theme/scripts/apply-theme.py" "$SYNC_SOURCE" >/dev/null 2>&1 \
        || run_user python3 "$TARGET_HOME/.config/theme/scripts/apply-theme.py" "$SYNC_SOURCE" >/dev/null 2>&1; then
        printf '%s\n' "Theme colors now follow: $SYNC_SOURCE"
    else
        printf '%s\n' 'Warning: could not extract colors from the current wallpaper; pick a wallpaper once to sync them.' >&2
    fi
else
    printf '%s\n' 'No current wallpaper found; colors will sync the first time you pick a wallpaper.'
fi

if run_session hyprctl instances >/dev/null 2>&1; then
    printf '%s\n' '==> Applying DoiZ to the current Hyprland session'
    run_session hyprctl reload >/dev/null 2>&1 || true
    if [ "$CURSOR_OK" -eq 1 ]; then
        run_session hyprctl setcursor "$CURSOR_THEME" "$CURSOR_SIZE" >/dev/null 2>&1 || true
    fi
    run_session qs kill -c mediapopup >/dev/null 2>&1 || true
    run_session qs kill -c cavadesk >/dev/null 2>&1 || true
    run_session qs kill -c spidertrail >/dev/null 2>&1 || true
    run_session pkill -x doiz-bar >/dev/null 2>&1 || true
    run_session qs kill -c bar >/dev/null 2>&1 || true
    run_session bash -c 'pkill -x waybar >/dev/null 2>&1 || true; setsid -f "$HOME/.config/hypr/scripts/doiz-session" </dev/null >/dev/null 2>&1'
fi

printf '%s\n' '==> Starting fcitx5 with the system tray icon'
run_user mkdir -p "$TARGET_HOME/.config/environment.d"
run_user rm -f "$TARGET_HOME/.config/environment.d/fcitx5.conf"
if run_session hyprctl instances >/dev/null 2>&1; then
    sleep 4
    if ! run_user pgrep -x fcitx5 >/dev/null 2>&1; then
        run_session setsid -f systemd-run --user --scope --quiet fcitx5 -d --replace </dev/null >/dev/null 2>&1 \
            || run_session setsid -f fcitx5 -d --replace </dev/null >/dev/null 2>&1 || true
    fi
    sleep 2
    run_session fcitx5-remote -r >/dev/null 2>&1 || true
    if run_user pgrep -x fcitx5 >/dev/null 2>&1; then
        printf '%s\n' 'fcitx5 is running; its tray icon appears in the bar (open the 󰇘 drawer, right-click it for Configure).'
    else
        printf '%s\n' 'Warning: fcitx5 did not start; it will start automatically at the next login.' >&2
    fi
else
    printf '%s\n' 'No Hyprland session found; fcitx5 and its tray icon start automatically at the next login.'
fi

printf '%s\n' '==> Running installation checks'
FAIL=0
for bin in hyprland qs eglinfo kitty alacritty btop cava awww awww-daemon grim slurp wl-copy wl-paste cliphist rofi rofimoji wlogout playerctl playerctld brightnessctl nmcli wpctl upower notify-send fcitx5 fcitx5-configtool python3 socat ffmpeg mpv mpvpaper wf-recorder hyprpicker hypridle hyprctl fish fc-cache gsettings qt6ct jq socat timeout pgrep; do
    if ! run_user bash -c 'command -v "$1" >/dev/null 2>&1' _ "$bin"; then
        printf 'missing: %s\n' "$bin" >&2
        FAIL=1
    fi
done

for file in \
    "$TARGET_HOME/.config/hypr/hyprland.lua" \
    "$TARGET_HOME/.config/electron-flags.conf" \
    "$TARGET_HOME/.config/code-flags.conf" \
    "$TARGET_HOME/.config/discord-flags.conf" \
    "$TARGET_HOME/.config/spotify-flags.conf" \
    "$TARGET_HOME/.config/quickshell/bar/shell.qml" \
    "$TARGET_HOME/.config/quickshell/bar/cava.conf" \
    "$TARGET_HOME/.config/quickshell/controlcenter/shell.qml" \
    "$TARGET_HOME/.config/hypr/scripts/doiz-session" \
    "$TARGET_HOME/.config/hypr/scripts/doiz-bar" \
    "$TARGET_HOME/.config/hypr/scripts/dark-mode.sh" \
    "$TARGET_HOME/.config/hypr/scripts/restore-wallpaper.sh" \
    "$TARGET_HOME/.config/hypr/scripts/video-wallpaper.sh" \
    "$TARGET_HOME/.config/hypr/scripts/video-wallpaper-stop.sh" \
    "$TARGET_HOME/.config/hypr/scripts/video-thumbnails.sh" \
    "$TARGET_HOME/.config/xdg-desktop-portal/hyprland-portals.conf" \
    "$TARGET_HOME/.config/hypr/scripts/infinite-desktop/infinite_desktop_core.py" \
    "$TARGET_HOME/.config/hypr/scripts/infinite-desktop/hypr_ipc.py"; do
    if [ ! -f "$file" ]; then
        printf 'missing: %s\n' "$file" >&2
        FAIL=1
    fi
done

if ! command -v luac >/dev/null 2>&1; then
    printf '%s\n' 'missing: luac' >&2
    FAIL=1
else
    for file in "$TARGET_HOME/.config/hypr"/*.lua "$TARGET_HOME/.config/hypr"/*/*.lua; do
        [ -f "$file" ] || continue
        if ! luac -p "$file"; then
            FAIL=1
        fi
    done
fi

if command -v python3 >/dev/null 2>&1; then
    while IFS= read -r -d '' file; do
        if ! PYTHONDONTWRITEBYTECODE=1 python3 -m py_compile "$file"; then
            FAIL=1
        fi
    done < <(find "$TARGET_HOME/.config/hypr/scripts" -type f -name '*.py' -print0)
fi

for file in "$TARGET_HOME/.config/hypr/scripts/"*.sh "$TARGET_HOME/.config/hypr/scripts/doiz-controlcenter" "$TARGET_HOME/.config/hypr/scripts/doiz-session" "$TARGET_HOME/.config/hypr/scripts/doiz-notifd"; do
    if [ -f "$file" ] && ! bash -n "$file"; then
        FAIL=1
    fi
done

if [ -f "$TARGET_HOME/.config/hypr/scripts/doiz-idle" ] && command -v python3 >/dev/null 2>&1; then
    if ! python3 -c 'import sys; compile(open(sys.argv[1]).read(), sys.argv[1], "exec")' "$TARGET_HOME/.config/hypr/scripts/doiz-idle"; then
        FAIL=1
    fi
fi

if [ "$FAIL" -ne 0 ]; then
    printf '%s\n' 'DoiZ installation checks failed.' >&2
    exit 1
fi

if run_user bash -c 'command -v eglinfo >/dev/null 2>&1'; then
    GL_RENDERER="$(run_session eglinfo -B 2>/dev/null | grep -i 'renderer' | head -n1 || true)"
    case "${GL_RENDERER,,}" in
        *llvmpipe*|*softpipe*|*swrast*)
            printf '%s\n' 'Warning: OpenGL is using software rendering (llvmpipe). The Black Hole effect will run in lite mode; check your GPU driver.' >&2
            ;;
    esac
    run_user rm -f "$TARGET_HOME/.local/state/doiz/gl-renderer"
fi

printf '%s\n' '' 'DoiZ installation completed.' 'Start or restart Hyprland to apply the full session configuration.'
printf '%s\n' 'Infinite Desktop v2: Super+Arrow navigates, Super+Shift+Arrow moves floating windows, Super+Alt+Arrow moves tiled windows, Super+Ctrl+Alt+Arrow resizes.' 'Super+Shift+A toggles Auto Arrange Grid; Super+V remains Clipboard.'
printf '%s\n' 'Dark Mode button: GTK, Firefox, Chromium, Electron and Qt follow it; The bar, Quickshell, btop, cava and kitty keep the wallpaper colors. Log out and back in once so xdg-desktop-portal picks up the session environment.'
printf '%s\n' 'fcitx5: the tray icon is in the bar (󰇘 drawer); right-click it > Configure (fcitx5-configtool) to add your input method. Apps that were already open must be reopened once; after that no restart is needed.' 'Wayland-native Electron flags are in ~/.config/{electron,code,discord,spotify}-flags.conf. Run games in Borderless Windowed, not exclusive Fullscreen.'
