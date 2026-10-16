#!/usr/bin/env python3
import argparse
import colorsys
import configparser
import fcntl
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import tomllib
from io import BytesIO
from pathlib import Path

HERE = Path(__file__).resolve().parent
SVG_ROOT = HERE / "svg"
SHAPES = ("soft", "original", "modern")
DEFAULT_SHAPE = os.environ.get("DOIZ_CURSOR_SHAPE", "modern")
SHAPE_SOURCE = {"soft": "original", "original": "original", "modern": "modern"}
SOFT_RADIUS = float(os.environ.get("DOIZ_CURSOR_ROUND", "4.5"))
SOFT_GAIN = 6
CONFIG = HERE / "x.build.toml"
THEME_CONF = HERE.parent / "theme" / "theme.conf"
BITMAP_SIZE = 256
XCURSOR_IMAGE = 0xFFFD0002
DYNAMIC_PREFIX = "DoiZ-Cursor-"
DYNAMIC_SLOTS = ("A", "B")
STATIC_NAME = "DoiZ-Cursor"
DEFAULT_SIZE = 24

DATA_HOME = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share")
CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
STATE_HOME = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local" / "state")
LOCK_FILE = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "doiz-cursor.lock"

FALLBACK = {
    "background": "#1A1D33",
    "foreground": "#D6DAED",
    "subtext": "#A5ABCD",
    "muted": "#6E76A0",
    "accent": "#6A85CC",
    "accent_alt": "#6D72A8",
    "blue": "#6A85CC",
    "cyan": "#617BCA",
    "green": "#81AA99",
    "red": "#B2729E",
    "yellow": "#AA978B",
}


def load_palette(path):
    palette = dict(FALLBACK)
    if path and Path(path).is_file():
        parser = configparser.ConfigParser(interpolation=None)
        parser.read(path, encoding="utf-8")
        if parser.has_section("colors"):
            for key in palette:
                value = parser.get("colors", key, fallback="").strip()
                if re.fullmatch(r"#[0-9A-Fa-f]{6}", value):
                    palette[key] = value.upper()
    return palette


def hex_color(value):
    value = value.strip()
    if not value.startswith("#"):
        value = "#" + value
    if not re.fullmatch(r"#[0-9A-Fa-f]{6}", value):
        raise argparse.ArgumentTypeError(f"invalid colour: {value}")
    return value.upper()


def theme_mode(path):
    parser = configparser.ConfigParser(interpolation=None)
    if path and Path(path).is_file():
        parser.read(path, encoding="utf-8")
    mode = parser.get("theme", "mode", fallback="dark").strip().lower()
    return mode if mode in ("dark", "light") else "dark"


def boost(rgb, mode):
    h, s, v = colorsys.rgb_to_hsv(*[channel / 255.0 for channel in rgb])
    if max(rgb) - min(rgb) <= 2:
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
    return (round(r * 255), round(g * 255), round(b * 255))


def hue_gap(first, second):
    gap = abs(first[0] - second[0])
    return min(gap, 1 - gap)


def to_hex(rgb):
    return "#{:02X}{:02X}{:02X}".format(*rgb)


def image_is_neutral(path):
    try:
        from PIL import Image

        im = Image.open(path).convert("RGB")
        im.thumbnail((96, 96))
        _, sat, val = im.convert("HSV").split()
        pairs = [(s, v) for s, v in zip(sat.tobytes(), val.tobytes()) if v >= 40]
    except Exception:
        return False
    weight = sum(v for _, v in pairs)
    return weight > 0 and sum(s * v for s, v in pairs) / weight / 255.0 < 0.12


def wallpaper_corners(path, mode):
    from colorthief import ColorThief

    palette = ColorThief(str(path)).get_palette(color_count=8, quality=10)
    if image_is_neutral(path):
        palette = [(lum, lum, lum) for lum in (round(0.299 * r + 0.587 * g + 0.114 * b) for r, g, b in palette)]
    candidates = list(dict.fromkeys(boost(rgb, mode) for rgb in palette))
    hsv = {rgb: colorsys.rgb_to_hsv(*[c / 255.0 for c in rgb]) for rgb in candidates}
    chosen = [candidates[0]]
    rest = [rgb for rgb in candidates[1:] if rgb not in chosen]
    while rest and len(chosen) < 4:
        best = max(rest, key=lambda rgb: min(hue_gap(hsv[rgb], hsv[c]) for c in chosen))
        chosen.append(best)
        rest.remove(best)
    step = 0
    while len(chosen) < 4:
        step += 1
        h, s, v = colorsys.rgb_to_hsv(*[c / 255.0 for c in chosen[0]])
        r, g, b = colorsys.hsv_to_rgb((h + 0.07 * step) % 1.0, s, v)
        chosen.append((round(r * 255), round(g * 255), round(b * 255)))
    return [to_hex(rgb) for rgb in chosen]


def current_wallpaper():
    try:
        value = (STATE_HOME / "doiz" / "current-wallpaper").read_text(encoding="utf-8").strip()
    except OSError:
        return None
    return Path(value) if value and Path(value).is_file() else None


def color_map(palette, fill, outline, accent, corners=None):
    accent = accent or palette["accent"]
    corners = corners or [palette["cyan"], palette["red"], palette["green"], palette["yellow"]]
    return {
        "#00FF00": fill,
        "#0000FF": outline,
        "#FF0000": fill,
        "#FE0000": palette["red"],
        "#F05024": corners[1],
        "#F27400": palette["yellow"],
        "#FCB813": corners[3],
        "#7EBA41": corners[2],
        "#06B231": palette["green"],
        "#0A6857": palette["green"],
        "#32A0DA": corners[0],
        "#179DD8": palette["blue"],
        "#4FADDF": corners[0],
        "#F1613A": corners[1],
        "#96C865": corners[2],
        "#FDBE2A": corners[3],
        "#5F3BE4": palette["accent_alt"],
        "#2C2C2C": palette["muted"],
        "#606060": palette["subtext"],
    }


def recolor(text, mapping):
    def swap(match):
        return mapping.get(match.group(0).upper(), match.group(0))

    return re.sub(r"#[0-9A-Fa-f]{6}\b", swap, text)


def soften_markup(text):
    def add_round(match):
        tag = match.group(0)
        if "stroke-width" not in tag:
            return tag
        extra = ""
        if "stroke-linejoin" not in tag:
            extra += ' stroke-linejoin="round"'
        if "stroke-linecap" not in tag:
            extra += ' stroke-linecap="round"'
        return tag[:-2] + extra + "/>" if tag.endswith("/>") else tag

    return re.sub(r"<path\b[^>]*/>", add_round, text)


def soften_bitmap(image, edge_color):
    from PIL import Image, ImageFilter

    blurred = image.getchannel("A").filter(ImageFilter.GaussianBlur(SOFT_RADIUS))
    lut = [max(0, min(255, round(128 + (value - 128) * SOFT_GAIN))) for value in range(256)]
    alpha = blurred.point(lut)
    canvas = Image.new("RGBA", image.size, edge_color)
    canvas.alpha_composite(image)
    canvas.putalpha(alpha)
    return canvas


def render_bitmaps(mapping, shape):
    import cairosvg
    from PIL import Image

    bitmaps = {}
    for svg in sorted((SVG_ROOT / SHAPE_SOURCE[shape]).rglob("*.svg")):
        text = recolor(svg.read_text(encoding="utf-8"), mapping)
        if shape == "soft":
            text = soften_markup(text)
        png = cairosvg.svg2png(
            bytestring=text.encode("utf-8"),
            output_width=BITMAP_SIZE,
            output_height=BITMAP_SIZE,
        )
        image = Image.open(BytesIO(png)).convert("RGBA")
        bitmaps[svg.stem] = soften_bitmap(image, mapping["#0000FF"]) if shape == "soft" else image
    return bitmaps


def frames_for(bitmaps, pattern):
    stem = pattern[:-4] if pattern.endswith(".png") else pattern
    if "*" not in stem:
        return [bitmaps[stem]] if stem in bitmaps else []
    regex = re.compile("^" + re.escape(stem).replace(r"\*", ".*") + "$")
    return [bitmaps[key] for key in sorted(bitmaps) if regex.match(key)]


def encode_pixels(image):
    from PIL import Image

    premultiplied = image.convert("RGBa")
    r, g, b, a = premultiplied.split()
    return Image.merge("RGBA", (b, g, r, a)).tobytes()


def xcursor_bytes(frames, sizes, xhot, yhot, delay):
    from PIL import Image

    chunks = []
    for size in sizes:
        scale = size / BITMAP_SIZE
        hot_x = min(size - 1, max(0, round(xhot * scale)))
        hot_y = min(size - 1, max(0, round(yhot * scale)))
        for frame in frames:
            scaled = frame.resize((size, size), Image.LANCZOS)
            header = struct.pack(
                "<9I",
                36,
                XCURSOR_IMAGE,
                size,
                1,
                size,
                size,
                hot_x,
                hot_y,
                delay if len(frames) > 1 else 0,
            )
            chunks.append((size, header + encode_pixels(scaled)))

    position = 16 + 12 * len(chunks)
    table = b""
    body = b""
    for size, chunk in chunks:
        table += struct.pack("<3I", XCURSOR_IMAGE, size, position + len(body))
        body += chunk
    return struct.pack("<4s3I", b"Xcur", 16, 0x10000, len(chunks)) + table + body


def build_theme(bitmaps, target, name, comment):
    config = tomllib.loads(CONFIG.read_text(encoding="utf-8"))["cursors"]
    fallback = config.pop("fallback_settings")
    cursors = target / "cursors"
    if target.exists():
        shutil.rmtree(target)
    cursors.mkdir(parents=True)

    for key, entry in config.items():
        frames = frames_for(bitmaps, entry["png"])
        if not frames:
            continue
        sizes = entry.get("x11_sizes", fallback["x11_sizes"])
        data = xcursor_bytes(
            frames,
            sizes,
            entry.get("x_hotspot", fallback["x_hotspot"]),
            entry.get("y_hotspot", fallback["y_hotspot"]),
            entry.get("x11_delay", fallback["x11_delay"]),
        )
        cursor_name = entry.get("x11_name", key)
        (cursors / cursor_name).write_bytes(data)
        for link in entry.get("x11_symlinks", []):
            path = cursors / link
            if path.is_symlink() or path.exists():
                path.unlink()
            os.symlink(cursor_name, path)

    (target / "index.theme").write_text(
        f"[Icon Theme]\nName={name}\nComment={comment}\nInherits=Bibata-Modern-Classic\n",
        encoding="utf-8",
    )


def replace_tree(source, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_name(destination.name + ".new")
    if temporary.exists():
        shutil.rmtree(temporary)
    shutil.copytree(source, temporary, symlinks=True)
    if destination.exists():
        shutil.rmtree(destination)
    os.rename(temporary, destination)


def set_ini_keys(path, section, values):
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = path.read_text(encoding="utf-8").splitlines() if path.exists() else []
    output = []
    inside = False
    seen = False
    written = set()

    def flush():
        for key, value in values.items():
            if key not in written:
                output.append(f"{key}={value}")
                written.add(key)

    for line in lines:
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            if inside:
                flush()
            inside = stripped[1:-1] == section
            seen = seen or inside
        elif inside and "=" in stripped and not stripped.startswith(("#", ";")):
            key = stripped.split("=", 1)[0].strip()
            if key in values:
                output.append(f"{key}={values[key]}")
                written.add(key)
                continue
        output.append(line)

    if inside:
        flush()
    if not seen:
        output.append(f"[{section}]")
        flush()

    path.write_text("\n".join(output) + "\n", encoding="utf-8")


def current_slot():
    try:
        return (STATE_HOME / "doiz" / "cursor-slot").read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def remember_slot(slot):
    state = STATE_HOME / "doiz"
    state.mkdir(parents=True, exist_ok=True)
    (state / "cursor-slot").write_text(slot + "\n", encoding="utf-8")


def cursor_size():
    try:
        return int(os.environ.get("XCURSOR_SIZE", DEFAULT_SIZE))
    except ValueError:
        return DEFAULT_SIZE


def run_quiet(command):
    try:
        subprocess.run(
            command,
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        pass


def activate(name, size):
    for settings in (
        CONFIG_HOME / "gtk-3.0" / "settings.ini",
        CONFIG_HOME / "gtk-4.0" / "settings.ini",
    ):
        set_ini_keys(
            settings,
            "Settings",
            {"gtk-cursor-theme-name": name, "gtk-cursor-theme-size": str(size)},
        )

    set_ini_keys(
        DATA_HOME / "icons" / "default" / "index.theme",
        "Icon Theme",
        {"Name": "Default", "Inherits": name},
    )

    if shutil.which("gsettings"):
        run_quiet(["gsettings", "set", "org.gnome.desktop.interface", "cursor-theme", name])
        run_quiet(["gsettings", "set", "org.gnome.desktop.interface", "cursor-size", str(size)])

    if shutil.which("hyprctl") and os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        run_quiet(["hyprctl", "setcursor", name, str(size)])


def apply_dynamic(mapping, comment, shape):
    LOCK_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(LOCK_FILE, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        bitmaps = render_bitmaps(mapping, shape)
        slot = DYNAMIC_SLOTS[1] if current_slot() == DYNAMIC_SLOTS[0] else DYNAMIC_SLOTS[0]
        name = DYNAMIC_PREFIX + slot
        icons = DATA_HOME / "icons"

        with tempfile.TemporaryDirectory(prefix="doiz-cursor-") as tmp:
            built = Path(tmp) / name
            build_theme(bitmaps, built, name, comment)
            replace_tree(built, icons / name)

            static = Path(tmp) / STATIC_NAME
            build_theme(bitmaps, static, STATIC_NAME, comment)
            replace_tree(static, icons / STATIC_NAME)

        remember_slot(slot)
        activate(name, cursor_size())
    return name


def parse_args():
    parser = argparse.ArgumentParser(description="Build the DoiZ cursor theme")
    parser.add_argument("--name", default=STATIC_NAME)
    parser.add_argument("--out", type=Path, default=HERE)
    parser.add_argument("--theme-conf", type=Path, default=THEME_CONF)
    parser.add_argument("--fill", type=hex_color)
    parser.add_argument("--outline", type=hex_color)
    parser.add_argument("--accent", type=hex_color)
    parser.add_argument("--wallpaper", type=Path)
    parser.add_argument("--shape", choices=SHAPES, default=DEFAULT_SHAPE if DEFAULT_SHAPE in SHAPES else "modern")
    parser.add_argument("--install", action="store_true")
    parser.add_argument("--apply", action="store_true")
    return parser.parse_args()


def main():
    args = parse_args()
    try:
        import cairosvg
        import PIL
    except ImportError as error:
        print(f"missing dependency: {error.name} (pacman -S python-cairosvg python-pillow)", file=sys.stderr)
        return 1

    theme_conf = args.theme_conf
    if args.apply and not theme_conf.is_file():
        theme_conf = CONFIG_HOME / "theme" / "theme.conf"

    palette = load_palette(theme_conf)
    fill = args.fill or palette["background"]
    outline = args.outline or palette["foreground"]
    wallpaper = args.wallpaper or (current_wallpaper() if args.apply else None)
    corners = None
    if wallpaper is not None:
        try:
            corners = wallpaper_corners(wallpaper, theme_mode(theme_conf))
        except Exception as error:
            print(f"wallpaper colors skipped: {error}", file=sys.stderr)
    mapping = color_map(palette, fill, outline, args.accent, corners)
    comment = f"DoiZ cursors: Bibata {args.shape} shapes in the DoiZ palette"

    if args.apply:
        print(f"applied {apply_dynamic(mapping, comment, args.shape)}")
        return 0

    bitmaps = render_bitmaps(mapping, args.shape)
    destination = args.out / args.name
    with tempfile.TemporaryDirectory(prefix="doiz-cursor-") as tmp:
        built = Path(tmp) / args.name
        build_theme(bitmaps, built, args.name, comment)
        replace_tree(built, destination)
    print(f"{len(bitmaps)} bitmaps -> {destination}")

    if args.install:
        target = DATA_HOME / "icons" / args.name
        replace_tree(destination, target)
        print(f"installed -> {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
