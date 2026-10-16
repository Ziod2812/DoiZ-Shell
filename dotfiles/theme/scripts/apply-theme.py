#!/usr/bin/env python3
import configparser
import colorsys
import os
import re
import shutil
import signal
import subprocess
import sys
import time
import fcntl
import shutil
from pathlib import Path
from tempfile import NamedTemporaryFile

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_CONFIG = SCRIPT_DIR.parent.parent.resolve()

THEME_DIR = PROJECT_CONFIG / "theme"
THEME_FILE = THEME_DIR / "theme.conf"

BTOP_DIR = PROJECT_CONFIG / "btop"
BTOP_THEME_DIR = BTOP_DIR / "themes"
BTOP_THEME_FILE = BTOP_THEME_DIR / "doiz.theme"
BTOP_CONFIG_FILE = BTOP_DIR / "btop.conf"

CAVA_DIR = PROJECT_CONFIG / "cava"
CAVA_CONFIG_FILE = CAVA_DIR / "config"
CAVA_TERMINAL_FILE = CAVA_DIR / "config_terminal"

HYPR_BORDER_FILE = PROJECT_CONFIG / "hypr" / "local" / "theme-border.lua"

GTK_TEMPLATE_FILE = PROJECT_CONFIG / "gtk-3.0" / "gtk.css.template"
GTK_CSS_FILE = PROJECT_CONFIG / "gtk-3.0" / "gtk.css"

GTK_SCHEMA = "org.gnome.desktop.interface"
GTK_THEME_PREFIX = "DoiZ-Dyn-"
LOCK_FILE = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "doiz-apply-theme.lock"

DATA_HOME = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share")
CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")

GTK_THEMES_DIR = DATA_HOME / "themes"
GTK3_SETTINGS_FILE = CONFIG_HOME / "gtk-3.0" / "settings.ini"
GTK4_SETTINGS_FILE = CONFIG_HOME / "gtk-4.0" / "settings.ini"
QT6CT_CONFIG_FILE = PROJECT_CONFIG / "qt6ct" / "qt6ct.conf"

ICON_THEME_PREFIX = "DoiZ-Icons-"
ICON_SOURCE_THEME = "Papirus"
ICON_STYLE_VERSION = "2"
ICON_SEARCH_DIRS = (Path.home() / ".icons", DATA_HOME / "icons", Path("/usr/share/icons"))
ICON_BLUE_MARKER = "#5294e2"
ICON_BLUE_SATURATION = 0.71
ICON_BLUE_LIGHTNESS = 0.60
ICON_BLUE_HUE_RANGE = (196.0, 228.0)
ICON_HEX_PATTERN = re.compile(r"#[0-9a-fA-F]{6}\b")

def clamp(value):
    return max(0, min(255, int(round(value))))

def rgb_to_hex(rgb):
    return "#{:02X}{:02X}{:02X}".format(
        clamp(rgb[0]),
        clamp(rgb[1]),
        clamp(rgb[2])
    )

def mix(a, b, amount):
    return (
        clamp(a[0] * (1 - amount) + b[0] * amount),
        clamp(a[1] * (1 - amount) + b[1] * amount),
        clamp(a[2] * (1 - amount) + b[2] * amount)
    )

def rgba(color, alpha):
    value = color.lstrip("#")

    r = int(value[0:2], 16)
    g = int(value[2:4], 16)
    b = int(value[4:6], 16)

    return f"rgba({r}, {g}, {b}, {alpha})"

NEUTRAL_IMAGE_SAT = 0.12

def is_neutral(rgb):
    return max(rgb) - min(rgb) <= 2

def gray_of(rgb):
    g = clamp(0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2])
    return (g, g, g)

def image_is_neutral(path):
    try:
        from PIL import Image

        im = Image.open(path).convert("RGB")
        im.thumbnail((96, 96))
        _, sat, val = im.convert("HSV").split()
        s_bytes, v_bytes = sat.tobytes(), val.tobytes()
    except Exception:
        return False

    total = weight = 0.0

    for s, v in zip(s_bytes, v_bytes):
        if v >= 40:
            total += s * v
            weight += v

    return weight > 0 and (total / weight) / 255.0 < NEUTRAL_IMAGE_SAT

def boost_color(rgb, mode="dark"):
    r, g, b = [x / 255.0 for x in rgb]

    h, s, v = colorsys.rgb_to_hsv(r, g, b)

    if is_neutral(rgb):
        s = 0.0
    elif s < 0.18:
        s = 0.48
    elif s < 0.35:
        s = 0.55
    else:
        s = min(0.82, s * 1.35)

    if mode == "light":
        v = max(0.36, min(0.60, v))
    else:
        v = max(0.55, min(0.88, v + 0.12))

    r, g, b = colorsys.hsv_to_rgb(h, s, v)

    return (
        clamp(r * 255),
        clamp(g * 255),
        clamp(b * 255)
    )

def load_theme():
    parser = configparser.ConfigParser()

    if THEME_FILE.exists():
        parser.read(THEME_FILE)

    for section in (
        "theme",
        "colors",
        "dynamic",
        "targets"
    ):
        if not parser.has_section(section):
            parser.add_section(section)

    return parser

def write_atomic(path, content):
    path.parent.mkdir(
        parents=True,
        exist_ok=True
    )

    with NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        dir=path.parent,
        prefix=f".{path.name}.",
        suffix=".tmp",
        delete=False
    ) as temporary:
        temporary.write(content)
        temporary.flush()
        os.fsync(temporary.fileno())
        temporary_path = Path(temporary.name)

    os.replace(
        temporary_path,
        path
    )

def keep_dynamic_flag(parser):
    fresh = configparser.ConfigParser()

    try:
        fresh.read(THEME_FILE)
        value = fresh.get("dynamic", "enabled")
    except (configparser.Error, OSError):
        return

    if not parser.has_section("dynamic"):
        parser.add_section("dynamic")

    parser["dynamic"]["enabled"] = value

def save_theme(parser, colors, mode="dark"):
    parser["theme"]["name"] = "DoiZ"
    parser["theme"]["mode"] = mode

    for key, value in colors.items():
        parser["colors"][key] = value

    for key, value in (
        ("enabled", "true"),
        ("source", "wallpaper"),
        ("extractor", "colorthief"),
        ("update_on_wallpaper_change", "true")
    ):
        parser["dynamic"].setdefault(key, value)

    for key in ("quickshell", "btop", "cava", "kitty", "rofi", "gtk"):
        parser["targets"].setdefault(key, "true")

    from io import StringIO

    keep_dynamic_flag(parser)

    output = StringIO()
    parser.write(output)

    write_atomic(
        THEME_FILE,
        output.getvalue()
    )

PALETTES = {
    "dark": {
        "background": (18, 20, 31),
        "surface": (31, 34, 49),
        "surface_alt": (49, 52, 69),
        "foreground": (235, 238, 250),
        "subtext": (205, 211, 230),
        "muted": (142, 150, 173),
        "blue": (137, 180, 250),
        "cyan": (122, 162, 247),
        "green": (166, 227, 161),
        "red": (243, 139, 168),
        "yellow": (230, 197, 138),
    },
    "light": {
        "background": (244, 245, 251),
        "surface": (230, 233, 244),
        "surface_alt": (213, 217, 234),
        "foreground": (27, 30, 46),
        "subtext": (62, 67, 90),
        "muted": (104, 111, 138),
        "blue": (40, 80, 190),
        "cyan": (20, 105, 170),
        "green": (30, 125, 75),
        "red": (185, 45, 85),
        "yellow": (150, 100, 10),
    },
}

WEIGHTS = {
    "dark": {
        "background": 0.82,
        "surface": 0.64,
        "surface_alt": 0.48,
        "foreground": 0.88,
        "subtext": 0.72,
        "muted": 0.60,
        "blue": 0.58,
        "cyan": 0.58,
        "green": 0.64,
        "red": 0.64,
        "yellow": 0.64,
    },
    "light": {
        "background": 0.95,
        "surface": 0.91,
        "surface_alt": 0.85,
        "foreground": 0.90,
        "subtext": 0.80,
        "muted": 0.70,
        "blue": 0.75,
        "cyan": 0.75,
        "green": 0.75,
        "red": 0.75,
        "yellow": 0.75,
    },
}

def hex_to_rgb(value):
    value = value.strip().lstrip("#")
    return (
        int(value[0:2], 16),
        int(value[2:4], 16),
        int(value[4:6], 16)
    )

def build_palette(dominant, mode):
    base = PALETTES[mode]
    accent = boost_color(dominant, mode)

    if is_neutral(accent):
        base = {
            key: gray_of(value) if key not in ("green", "red", "yellow")
            else mix(value, gray_of(value), 0.6)
            for key, value in base.items()
        }

    weights = WEIGHTS[mode]

    colors = {
        key: rgb_to_hex(mix(accent, base[key], weights[key]))
        for key in weights
    }

    accent_alt = mix(accent, (255, 255, 255), 0.24)

    if mode == "light":
        accent_dark = mix(accent, (255, 255, 255), 0.72)
    else:
        accent_dark = mix(accent, (0, 0, 0), 0.40)

    colors["accent"] = rgb_to_hex(accent)
    colors["accent_alt"] = rgb_to_hex(accent_alt)
    colors["accent_dark"] = rgb_to_hex(accent_dark)
    colors["dominant"] = rgb_to_hex(dominant)

    return colors

def extract_colors(wallpaper, mode="dark"):
    from colorthief import ColorThief

    dominant = ColorThief(str(wallpaper)).get_color(quality=10)

    if image_is_neutral(wallpaper):
        dominant = gray_of(dominant)

    return build_palette(dominant, mode)

def render_btop(colors):
    BTOP_THEME_DIR.mkdir(
        parents=True,
        exist_ok=True
    )

    theme = f'''theme[main_bg]="{colors["background"]}"
theme[main_fg]="{colors["foreground"]}"

theme[title]="{colors["foreground"]}"
theme[hi_fg]="{colors["accent"]}"

theme[selected_bg]="{colors["surface"]}"
theme[selected_fg]="{colors["accent"]}"

theme[inactive_fg]="{colors["muted"]}"
theme[graph_text]="{colors["subtext"]}"
theme[meter_bg]="{colors["surface_alt"]}"

theme[proc_misc]="{colors["blue"]}"
theme[cpu_box]="{colors["accent"]}"
theme[mem_box]="{colors["green"]}"
theme[net_box]="{colors["blue"]}"
theme[proc_box]="{colors["cyan"]}"
theme[div_line]="{colors["surface_alt"]}"

theme[temp_start]="{colors["green"]}"
theme[temp_mid]="{colors["yellow"]}"
theme[temp_end]="{colors["red"]}"

theme[cpu_start]="{colors["blue"]}"
theme[cpu_mid]="{colors["cyan"]}"
theme[cpu_end]="{colors["accent"]}"

theme[free_start]="{colors["green"]}"
theme[free_mid]="{colors["blue"]}"
theme[free_end]="{colors["accent"]}"

theme[cached_start]="{colors["blue"]}"
theme[cached_mid]="{colors["cyan"]}"
theme[cached_end]="{colors["accent"]}"

theme[available_start]="{colors["yellow"]}"
theme[available_mid]="{colors["red"]}"
theme[available_end]="{colors["red"]}"

theme[used_start]="{colors["green"]}"
theme[used_mid]="{colors["cyan"]}"
theme[used_end]="{colors["blue"]}"

theme[download_start]="{colors["blue"]}"
theme[download_mid]="{colors["cyan"]}"
theme[download_end]="{colors["accent"]}"

theme[upload_start]="{colors["accent"]}"
theme[upload_mid]="{colors["red"]}"
theme[upload_end]="{colors["red"]}"

theme[process_start]="{colors["blue"]}"
theme[process_mid]="{colors["cyan"]}"
theme[process_end]="{colors["accent"]}"

theme[read_start]="{colors["blue"]}"
theme[read_mid]="{colors["cyan"]}"
theme[read_end]="{colors["green"]}"

theme[write_start]="{colors["accent"]}"
theme[write_mid]="{colors["yellow"]}"
theme[write_end]="{colors["red"]}"

theme[proc_pause_bg]="{colors["surface"]}"
theme[proc_follow_bg]="{colors["surface_alt"]}"
theme[proc_banner_bg]="{colors["surface"]}"
theme[proc_banner_fg]="{colors["foreground"]}"

theme[followed_bg]="{colors["surface"]}"
theme[followed_fg]="{colors["accent"]}"
'''

    write_atomic(
        BTOP_THEME_FILE,
        theme
    )

CAVA_TERMINAL_COLOR_SECTION = """[color]
gradient = 0
background = default
foreground = cyan
"""

CAVA_FALLBACK_CONFIG = """[general]
framerate = 60
autosens = 1
sensitivity = 180

[input]
method = pipewire
source = auto

[output]
method = ncurses
channels = mono

[smoothing]
monstercat = 1
waves = 0
noise_reduction = 60
"""

CAVA_COLOR_SECTION_PATTERN = re.compile(
    r"^\[color\][^\n]*\n.*?(?=^\[|\Z)",
    re.MULTILINE | re.DOTALL
)

def cava_with_colors(text, colors):
    section = CAVA_TERMINAL_COLOR_SECTION

    if CAVA_COLOR_SECTION_PATTERN.search(text):
        text = CAVA_COLOR_SECTION_PATTERN.sub(
            lambda _: section + "\n",
            text,
            count=1
        )
    else:
        text = text.rstrip() + "\n\n" + section

    return text.rstrip() + "\n"

def render_cava(colors):
    if CAVA_TERMINAL_FILE.is_file():
        base = CAVA_TERMINAL_FILE.read_text(encoding="utf-8")
    else:
        base = CAVA_FALLBACK_CONFIG

    write_atomic(
        CAVA_CONFIG_FILE,
        cava_with_colors(base, colors)
    )

def render_cava_terminal(colors):
    if not CAVA_TERMINAL_FILE.is_file():
        print(f"Cava terminal: missing {CAVA_TERMINAL_FILE}, skipped")
        return

    text = CAVA_TERMINAL_FILE.read_text(encoding="utf-8")

    write_atomic(
        CAVA_TERMINAL_FILE,
        cava_with_colors(text, colors)
    )

def find_user_pids(name):
    uid = os.getuid()
    pids = []

    for proc in Path("/proc").iterdir():
        if not proc.name.isdigit():
            continue

        try:
            if proc.stat().st_uid != uid:
                continue

            if (proc / "comm").read_text(encoding="utf-8").strip() != name:
                continue
        except OSError:
            continue

        pids.append(int(proc.name))

    return pids

def signal_user_processes(name, sig):
    count = 0

    for pid in find_user_pids(name):
        try:
            os.kill(pid, sig)
            count += 1
        except (ProcessLookupError, PermissionError):
            continue

    return count

def reload_cava_terminal():
    count = signal_user_processes("cava", signal.SIGUSR2)

    if count:
        print(f"Cava recolored: {count}")

def ensure_btop_config():
    BTOP_DIR.mkdir(
        parents=True,
        exist_ok=True
    )

    theme_path = str(
        BTOP_THEME_FILE.resolve()
    )

    if BTOP_CONFIG_FILE.exists():
        lines = BTOP_CONFIG_FILE.read_text(
            encoding="utf-8"
        ).splitlines()
    else:
        lines = []

    updated = []
    found = False

    for line in lines:
        stripped = line.strip()

        if (
            stripped.startswith(
                "color_theme"
            )
            and "=" in stripped
        ):
            updated.append(
                f'color_theme = "{theme_path}"'
            )

            found = True
        else:
            updated.append(line)

    if not found:
        updated.insert(
            0,
            f'color_theme = "{theme_path}"'
        )

    write_atomic(
        BTOP_CONFIG_FILE,
        "\n".join(
            updated
        ).rstrip() + "\n"
    )

def reload_btop():
    count = signal_user_processes("btop", signal.SIGUSR2)

    if count:
        print(f"Btop hot-reloaded: {count}")
    else:
        print("Btop: no running instance")

def ensure_bar():
    state = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local" / "state")

    if (state / "doiz" / "bar-off").exists():
        return

    script = CONFIG_HOME / "hypr" / "scripts" / "doiz-bar"

    if not script.is_file():
        return

    try:
        subprocess.Popen(
            [str(script)],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True
        )
    except OSError:
        pass

def render_hypr_border(colors):
    value = colors["subtext"].lstrip("#").lower()

    write_atomic(
        HYPR_BORDER_FILE,
        "return {\n"
        f'    active = "rgba({value}de)",\n'
        f'    inactive = "rgba({value}de)",\n'
        "}\n"
    )

def reload_hypr():
    active = None
    inactive = None

    try:
        text = HYPR_BORDER_FILE.read_text(encoding="utf-8")
        active = re.search(r'active\s*=\s*"([^"]+)"', text)
        inactive = re.search(r'inactive\s*=\s*"([^"]+)"', text)
    except OSError:
        pass

    if active and inactive:
        expr = (
            "hl.config({ general = { col = { "
            f'active_border = "{active.group(1)}", '
            f'inactive_border = "{inactive.group(1)}" '
            "} } })"
        )

        try:
            result = subprocess.run(
                ["hyprctl", "eval", expr],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=5
            )

            if result.returncode == 0:
                return
        except (FileNotFoundError, subprocess.TimeoutExpired):
            pass

    try:
        subprocess.run(
            ["hyprctl", "reload"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=5
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        print("hyprctl not available, skipped")

def on_color(hex_color):
    r, g, b = hex_to_rgb(hex_color)
    lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255

    return "#101218" if lum > 0.55 else "#FFFFFF"

KITTY_RED_DARK = "#E06C75"
KITTY_RED_LIGHT = "#C53B4A"

def render_kitty(colors, mode):
    if mode == "light":
        red = KITTY_RED_LIGHT
        ansi = [
            colors["foreground"], red, colors["green"],
            colors["yellow"], colors["blue"], colors["accent"],
            colors["accent"], colors["surface_alt"],
            colors["muted"], red, colors["green"],
            colors["yellow"], colors["blue"], colors["accent"],
            colors["accent"], colors["background"],
        ]
        opacity = "0.88"
    else:
        red = KITTY_RED_DARK
        ansi = [
            colors["surface"], red, colors["green"],
            colors["yellow"], colors["blue"], colors["accent_alt"],
            colors["accent"], colors["subtext"],
            colors["muted"], red, colors["green"],
            colors["yellow"], colors["blue"], colors["accent_alt"],
            colors["accent"], colors["foreground"],
        ]
        opacity = "0.20"

    selection = rgb_to_hex(
        mix(hex_to_rgb(colors["background"]), hex_to_rgb(colors["accent"]), 0.35)
    )

    lines = [
        f"foreground {colors['foreground']}",
        f"background {colors['background']}",
        f"background_opacity {opacity}",
        "",
        f"cursor {colors['accent']}",
        f"cursor_text_color {colors['background']}",
        f"selection_foreground {colors['foreground']}",
        f"selection_background {selection}",
        "",
    ]

    lines += [f"color{i} {c}" for i, c in enumerate(ansi)]

    write_atomic(
        PROJECT_CONFIG / "kitty" / "theme.conf",
        "\n".join(lines) + "\n"
    )

def reload_kitty():
    subprocess.run(
        ["pkill", "-USR1", "-u", str(os.getuid()), "-x", "kitty"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )

def set_ini_keys(path, section, values):
    lines = path.read_text(encoding="utf-8").splitlines() if path.exists() else []
    header = f"[{section}]"
    out = []
    in_section = False
    seen_section = False
    pending = dict(values)

    def flush():
        for key, value in pending.items():
            out.append(f"{key}={value}")
        pending.clear()

    for line in lines:
        stripped = line.strip()

        if stripped.startswith("[") and stripped.endswith("]"):
            if in_section:
                flush()
            in_section = stripped == header
            seen_section = seen_section or in_section
            out.append(line)
            continue

        if in_section and "=" in line:
            key = line.split("=", 1)[0].strip()
            if key in pending:
                out.append(f"{key}={pending.pop(key)}")
                continue

        out.append(line)

    if in_section:
        flush()

    if not seen_section:
        out += [header]
        flush()

    write_atomic(path, "\n".join(out).rstrip() + "\n")

def render_qt6ct(colors, mode):
    def rgb(name):
        return hex_to_rgb(colors[name])

    def q(value):
        if isinstance(value, str):
            value = hex_to_rgb(value)
        return "#ff{:02x}{:02x}{:02x}".format(*value)

    white = (255, 255, 255)
    black = (0, 0, 0)
    fg, bg = rgb("foreground"), rgb("background")
    surface, alt = rgb("surface"), rgb("surface_alt")
    muted, accent = rgb("muted"), rgb("accent")

    def build(text, button_text):
        return [
            q(text), q(surface), q(mix(surface, white, 0.5)),
            q(mix(surface, white, 0.25)), q(mix(bg, black, 0.35)),
            q(alt), q(text), q(white), q(button_text),
            q(surface), q(bg), q(black), q(accent),
            q(on_color(colors["accent"])), q(accent),
            q(rgb("accent_alt")), q(alt), q(black), q(surface),
            q(fg), q(muted), q(accent),
        ]

    active = ", ".join(build(fg, fg))
    disabled = ", ".join(build(muted, muted))

    scheme = PROJECT_CONFIG / "qt6ct" / "colors" / "doiz.conf"

    write_atomic(
        scheme,
        "[ColorScheme]\n"
        f"active_colors={active}\n"
        f"inactive_colors={active}\n"
        f"disabled_colors={disabled}\n"
    )

    set_ini_keys(
        PROJECT_CONFIG / "qt6ct" / "qt6ct.conf",
        "Appearance",
        {
            "custom_palette": "true",
            "color_scheme_path": str(scheme),
            "style": "Fusion",
        }
    )

def shade(color, factor):
    value = color.lstrip("#")
    parts = [max(0, min(255, int(int(value[i:i + 2], 16) * factor))) for i in (0, 2, 4)]

    return "#%02x%02x%02x" % tuple(parts)

def purge_thumbnail_cache():
    try:
        subprocess.run(["pkill", "-u", str(os.getuid()), "-x", "tumblerd"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False, timeout=5)
    except (OSError, subprocess.SubprocessError):
        pass

    cache = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "thumbnails"

    for size in ("normal", "large", "x-large", "xx-large", "fail"):
        shutil.rmtree(cache / size, ignore_errors=True)

def render_gtk_css(colors):
    if not GTK_TEMPLATE_FILE.is_file():
        return ""

    text = GTK_TEMPLATE_FILE.read_text(encoding="utf-8")

    replacements = {
        "@BACKGROUND@": colors["background"],
        "@FOREGROUND@": colors["foreground"],
        "@SUBTEXT@": colors["subtext"],
        "@MUTED@": colors["muted"],
        "@ACCENT@": colors["accent"],
        "@ACCENT_ALT@": colors["accent_alt"],
        "@SURFACE@": colors["surface"],
        "@BG_WINDOW@": rgba(colors["surface"], "0.14"),
        "@BG_POPUP@": rgba(shade(colors["background"], 0.5), "0.88"),
        "@BG_MSGBOX@": rgba(shade(colors["background"], 0.5), "0.65"),
        "@BG_DIALOG@": rgba(colors["surface"], "0.42"),
        "@BG_CONTENT@": rgba(colors["surface"], "0.30"),
        "@BG_FIELD@": rgba(colors["surface"], "0.40"),
        "@BG_SELECT@": rgba(colors["accent_alt"], "0.40"),
        "@BORDER@": rgba(colors["accent_alt"], "0.50"),
        "@ACCENT_ALPHA@": rgba(colors["accent_alt"], "0.28"),
        "@BG_SELECT_OVER_HOVER@": rgba(colors["accent_alt"], "0.17"),
        "@ACCENT_STRONG@": rgba(colors["accent_alt"], "0.35"),
        "@MUTED_ALPHA@": rgba(colors["muted"], "0.55"),
    }

    for key, value in replacements.items():
        text = text.replace(key, value)

    return text

def gsettings_get(key):
    try:
        result = subprocess.run(
            ["gsettings", "get", GTK_SCHEMA, key],
            capture_output=True,
            text=True,
            timeout=5
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return ""

    return result.stdout.strip().strip("'")

def gsettings_set(key, value):
    try:
        subprocess.run(
            ["gsettings", "set", GTK_SCHEMA, key, value],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=5
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        print("gsettings not available, GTK theme switch skipped")

def gtk_base_import(base, sys_mode):
    names = ["gtk-dark.css", "gtk.css"] if sys_mode == "dark" else ["gtk.css"]

    for root in (Path.home() / ".themes", GTK_THEMES_DIR, Path("/usr/share/themes")):
        for name in names:
            candidate = root / base / "gtk-3.0" / name

            if candidate.is_file():
                return candidate.as_uri()

    variant = "gtk-contained-dark.css" if sys_mode == "dark" else "gtk-contained.css"

    return f"resource:///org/gtk/libgtk/theme/Adwaita/{variant}"

def write_gtk_theme(name, base, sys_mode, css):
    theme_dir = GTK_THEMES_DIR / name

    write_atomic(
        theme_dir / "index.theme",
        "[Desktop Entry]\n"
        "Type=X-GNOME-Metatheme\n"
        f"Name={name}\n"
        "Comment=DoiZ dynamic GTK theme\n"
        "Encoding=UTF-8\n\n"
        "[X-GNOME-Metatheme]\n"
        f"GtkTheme={name}\n"
    )

    content = f'@import url("{gtk_base_import(base, sys_mode)}");\n\n{css}'

    write_atomic(theme_dir / "gtk-3.0" / "gtk.css", content)
    write_atomic(theme_dir / "gtk-3.0" / "gtk-dark.css", content)

def resolve_gtk_base(parser, sys_mode, override):
    current = gsettings_get("gtk-theme")
    stored = parser["theme"].get("gtk_base", "").strip()

    if override:
        return override

    if current and not current.startswith(GTK_THEME_PREFIX):
        return current

    if stored:
        return stored

    return "Adwaita-dark" if sys_mode == "dark" else "Adwaita"

def new_gtk_theme_name(current):
    while True:
        name = GTK_THEME_PREFIX + str(time.time_ns())[-12:]
        if name != current:
            return name
        time.sleep(0.001)

def remove_stale_gtk_themes(keep):
    if not GTK_THEMES_DIR.is_dir():
        return

    for entry in GTK_THEMES_DIR.iterdir():
        if entry.name.startswith(GTK_THEME_PREFIX) and entry.name != keep:
            shutil.rmtree(entry, ignore_errors=True)

def apply_gtk_theme(parser, colors, sys_mode, base_override=None):
    base = resolve_gtk_base(parser, sys_mode, base_override)
    current = gsettings_get("gtk-theme")

    name = new_gtk_theme_name(current)

    write_gtk_theme(name, base, sys_mode, render_gtk_css(colors))
    write_atomic(GTK_CSS_FILE, "\n")

    parser["theme"]["gtk_base"] = base
    write_parser(parser)

    set_ini_keys(GTK3_SETTINGS_FILE, "Settings", {"gtk-theme-name": name})
    gsettings_set("gtk-theme", name)
    remove_stale_gtk_themes(name)

def current_icon_themes():
    names = {gsettings_get("icon-theme")}
    parser = configparser.RawConfigParser(strict=False, interpolation=None)

    try:
        parser.read(GTK3_SETTINGS_FILE, encoding="utf-8")
        names.add(parser.get("Settings", "gtk-icon-theme-name", fallback="").strip())
    except (configparser.Error, OSError):
        pass

    return names

def new_icon_theme_name(in_use):
    while True:
        name = ICON_THEME_PREFIX + str(time.time_ns())[-12:]

        if name not in in_use:
            return name

        time.sleep(0.001)

def remove_stale_icon_themes(keep):
    icons_dir = DATA_HOME / "icons"

    if not icons_dir.is_dir():
        return

    for entry in icons_dir.iterdir():
        if entry.name.startswith(ICON_THEME_PREFIX) and entry.name not in keep:
            shutil.rmtree(entry, ignore_errors=True)

def find_icon_theme(name):
    for root in ICON_SEARCH_DIRS:
        candidate = root / name

        if (candidate / "index.theme").is_file():
            return candidate

    return None

def recolor_folder_hex(value, accent_hls):
    r, g, b = [x / 255.0 for x in hex_to_rgb(value)]
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    hue = h * 360.0

    if hue < ICON_BLUE_HUE_RANGE[0] or hue > ICON_BLUE_HUE_RANGE[1] or s < 0.3:
        return value

    accent_h, accent_l, accent_s = accent_hls
    new_s = min(1.0, s * accent_s / ICON_BLUE_SATURATION)
    new_l = min(0.95, l * accent_l / ICON_BLUE_LIGHTNESS)
    nr, ng, nb = colorsys.hls_to_rgb(accent_h, new_l, new_s)

    return rgb_to_hex((nr * 255, ng * 255, nb * 255)).lower()

def recolor_folder_svg(text, accent_hls):
    cache = {}

    def replace(match):
        key = match.group(0).lower()

        if key not in cache:
            cache[key] = recolor_folder_hex(key, accent_hls)

        return cache[key]

    return ICON_HEX_PATTERN.sub(replace, text)

def build_folder_icon_theme(source, target, base_name, name, accent_hls):
    if target.exists():
        shutil.rmtree(target)

    index = configparser.RawConfigParser(strict=False, interpolation=None)
    index.optionxform = str
    index.read(source / "index.theme", encoding="utf-8")

    directories = []

    for places in sorted(source.glob("*/places")):
        size_dir = places.parent.name
        rel = f"{size_dir}/places"

        if size_dir == "symbolic" or not index.has_section(rel):
            continue

        out = target / size_dir / "places"
        out.mkdir(parents=True, exist_ok=True)
        written = set()

        for entry in places.iterdir():
            if entry.is_symlink() or entry.suffix != ".svg":
                continue

            text = entry.read_text(encoding="utf-8", errors="ignore")

            if ICON_BLUE_MARKER not in text.lower():
                continue

            (out / entry.name).write_text(
                recolor_folder_svg(text, accent_hls),
                encoding="utf-8"
            )
            written.add(entry.name)

        places_real = Path(os.path.realpath(places))

        for entry in places.iterdir():
            if not entry.is_symlink():
                continue

            final = Path(os.path.realpath(entry))

            if final.parent == places_real and final.name in written:
                os.symlink(os.readlink(entry), out / entry.name)

        if not written:
            shutil.rmtree(target / size_dir)
            continue

        directories.append(rel)

    own = []

    try:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import doiz_icons

        own = doiz_icons.build(target, accent_hls, source)
    except Exception as exc:
        print(f"DoiZ icon set skipped: {exc}")

    lines = [
        "[Icon Theme]",
        f"Name={name}",
        "Comment=DoiZ icons (wallpaper accent)",
        f"Inherits={base_name}",
        "Directories=" + ",".join([rel for rel, _ in own] + directories),
        "",
    ]

    for rel, props in own:
        lines.append(f"[{rel}]")
        lines += [f"{key}={value}" for key, value in props.items()]
        lines.append("")

    for rel in directories:
        lines.append(f"[{rel}]")
        lines += [f"{key}={value}" for key, value in index.items(rel)]
        lines.append("")

    write_atomic(target / "index.theme", "\n".join(lines))

    return bool(directories or own)

def apply_icon_theme(dominant, sys_mode):
    source = find_icon_theme(ICON_SOURCE_THEME)

    if source is None:
        return False

    if sys_mode == "dark":
        base_name = os.environ.get("DOIZ_ICON_DARK") or "Papirus-Dark"
    else:
        base_name = os.environ.get("DOIZ_ICON_LIGHT") or "Papirus-Light"

    if find_icon_theme(base_name) is None:
        base_name = ICON_SOURCE_THEME

    accent = boost_color(hex_to_rgb(dominant), "dark")
    h, l, s = colorsys.rgb_to_hls(*[x / 255.0 for x in accent])
    l = max(0.54, min(0.66, l))
    s = 0.0 if is_neutral(accent) else max(0.42, min(0.62, s))

    state_home = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local" / "state")
    accent_file = state_home / "doiz" / "icon-accent"
    accent_text = f"{h:.4f} {l:.4f} {s:.4f} {ICON_STYLE_VERSION}\n"

    try:
        accent_changed = accent_file.read_text() != accent_text
    except OSError:
        accent_changed = True

    write_atomic(accent_file, accent_text)

    if accent_changed:
        purge_thumbnail_cache()

    in_use = {name for name in current_icon_themes() if name.startswith(ICON_THEME_PREFIX)}
    name = new_icon_theme_name(in_use)

    if not build_folder_icon_theme(source, DATA_HOME / "icons" / name, base_name, name, (h, l, s)):
        shutil.rmtree(DATA_HOME / "icons" / name, ignore_errors=True)
        return False

    set_ini_keys(GTK3_SETTINGS_FILE, "Settings", {"gtk-icon-theme-name": name})
    set_ini_keys(GTK4_SETTINGS_FILE, "Settings", {"gtk-icon-theme-name": name})
    set_ini_keys(QT6CT_CONFIG_FILE, "Appearance", {"icon_theme": name})
    gsettings_set("icon-theme", name)
    remove_stale_icon_themes(in_use | {name})

    return True

def apply_cursor_theme():
    builder = PROJECT_CONFIG / "cursor" / "build.py"

    if not builder.is_file():
        return False

    try:
        subprocess.Popen(
            [sys.executable, str(builder), "--apply"],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True
        )
    except OSError:
        return False

    return True

def usage():
    name = Path(sys.argv[0]).name
    print(f"Usage: {name} /path/to/wallpaper")
    print(f"       {name} --mode dark|light      (whole desktop)")
    print(f"       {name} --system dark|light    (GTK/Qt apps only; "
          "quickshell, btop, cava, kitty untouched)")
    print(f"       {name} --icons                (rebuild the folder icon colors)")
    print(f"       {name} ... --gtk-base THEME   (GTK theme to wrap)")
    sys.exit(1)

def write_parser(parser):
    from io import StringIO

    keep_dynamic_flag(parser)

    output = StringIO()
    parser.write(output)

    write_atomic(THEME_FILE, output.getvalue())

def save_system_mode(parser, sys_mode):
    parser["theme"]["system_mode"] = sys_mode
    write_parser(parser)

def pop_option(args, name):
    if name not in args:
        return None

    index = args.index(name)

    if index + 1 >= len(args):
        usage()

    value = args[index + 1]
    del args[index:index + 2]

    return value

def acquire_lock():
    LOCK_FILE.parent.mkdir(parents=True, exist_ok=True)
    handle = open(LOCK_FILE, "w")
    fcntl.flock(handle, fcntl.LOCK_EX)
    return handle

def main():
    lock = acquire_lock()
    args = sys.argv[1:]
    gtk_base = pop_option(args, "--gtk-base")
    parser = load_theme()
    mode = parser["theme"].get("mode", "dark")

    if mode not in PALETTES:
        mode = "dark"

    sys_mode = parser["theme"].get("system_mode", mode)

    if sys_mode not in PALETTES:
        sys_mode = mode

    if args == ["--icons"]:
        dominant = parser["colors"].get("dominant", "#1b1b1b")
        sys.exit(0 if apply_icon_theme(dominant, sys_mode) else 1)

    if len(args) == 2 and args[0] == "--system":
        if args[1] not in PALETTES:
            usage()

        dominant = hex_to_rgb(
            parser["colors"].get("dominant", "#1b1b1b")
        )

        save_system_mode(parser, args[1])
        render_qt6ct(build_palette(dominant, args[1]), args[1])
        apply_gtk_theme(
            parser,
            build_palette(dominant, mode),
            args[1],
            gtk_base
        )
        apply_icon_theme(rgb_to_hex(dominant), args[1])

        print(f"System mode: {args[1]}")
        return

    if len(args) == 2 and args[0] == "--mode":
        if args[1] not in PALETTES:
            usage()

        mode = args[1]
        sys_mode = mode
        dominant = hex_to_rgb(
            parser["colors"].get("dominant", "#1b1b1b")
        )
        colors = build_palette(dominant, mode)
        source = f"mode={mode}"

    elif len(args) == 1:
        if parser["dynamic"].get("enabled", "true").strip().lower() != "true":
            print("Wallpaper colors are turned off, theme left unchanged")
            sys.exit(0)

        wallpaper = Path(
            os.path.expandvars(os.path.expanduser(args[0]))
        ).resolve()

        if not wallpaper.is_file():
            print(f"Wallpaper not found: {wallpaper}")
            sys.exit(1)

        try:
            colors = extract_colors(wallpaper, mode)
        except Exception as error:
            print(f"Color extraction failed: {error}")
            sys.exit(1)

        source = str(wallpaper)

    else:
        usage()

    parser["theme"]["system_mode"] = sys_mode

    save_theme(parser, colors, mode)
    render_btop(colors)
    render_cava(colors)
    render_cava_terminal(colors)
    render_kitty(colors, mode)
    render_hypr_border(colors)

    if sys_mode == mode:
        qt_colors = colors
    else:
        qt_colors = build_palette(
            hex_to_rgb(colors["dominant"]),
            sys_mode
        )

    render_qt6ct(qt_colors, sys_mode)
    apply_gtk_theme(parser, colors, sys_mode, gtk_base)
    apply_icon_theme(colors["dominant"], sys_mode)
    apply_cursor_theme()
    ensure_btop_config()

    reload_btop()
    reload_kitty()
    time.sleep(0.4)
    reload_cava_terminal()
    reload_hypr()
    ensure_bar()

    print(f"Source: {source}")
    print(f"Mode: {mode}")
    print(f"System mode: {sys_mode}")
    print(f"Accent: {colors['accent']}")
    print(f"Theme: {THEME_FILE}")

if __name__ == "__main__":
    main()
