#!/usr/bin/env python3

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps

HOME = Path(os.path.expanduser("~"))
STATE = Path(os.environ.get("XDG_STATE_HOME") or HOME / ".local" / "state") / "doiz"
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config")
DEFAULT_ACCENT = (0.80, 0.58, 0.45)

AUDIO_EXT = {".mp3", ".flac", ".ogg", ".oga", ".opus", ".m4a", ".aac", ".wav", ".wma", ".mka", ".aiff", ".aif", ".weba"}
VIDEO_EXT = {".mp4", ".webm", ".mkv", ".mov", ".avi", ".m4v", ".flv", ".wmv", ".mpg", ".mpeg", ".ts", ".ogv"}

LOG = Path(os.environ.get("XDG_CACHE_HOME") or HOME / ".cache") / "doiz" / "thumbnailer.log"

def log(message):
    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        with LOG.open("a") as fh:
            fh.write(message + "\n")
    except OSError:
        pass

def which(name):
    path = os.environ.get("PATH", "") + os.pathsep + "/usr/bin:/usr/local/bin:/bin:/opt/bin"
    return shutil.which(name, path=path)

def video_frame(source, size):
    fd, tmp = tempfile.mkstemp(prefix="doiz-vthumb-", suffix=".png", dir=os.path.dirname(os.path.abspath(sys.argv[2])))
    os.close(fd)

    commands = []

    thumbnailer = which("ffmpegthumbnailer")
    if thumbnailer:
        commands.append([thumbnailer, "-i", source, "-o", tmp, "-s", str(size * 2), "-t", "10%", "-c", "png"])
        commands.append([thumbnailer, "-i", source, "-o", tmp, "-s", str(size * 2), "-t", "0", "-c", "png"])

    ffmpeg = which("ffmpeg")
    if ffmpeg:
        for offset in ("1", "0"):
            commands.append([ffmpeg, "-nostdin", "-y", "-loglevel", "error", "-ss", offset, "-i", source,
                             "-an", "-sn", "-frames:v", "1", "-vf", f"scale={size * 2}:-2", tmp])

    if not commands:
        log(f"no ffmpegthumbnailer/ffmpeg found for {source}")

    for command in commands:
        try:
            result = subprocess.run(
                command, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
                timeout=60, check=False,
            )
        except (OSError, subprocess.SubprocessError) as exc:
            log(f"{command[0]} failed on {source}: {exc}")
            continue
        if os.path.getsize(tmp) > 0:
            return tmp
        log(f"{command[0]} gave no frame for {source}: {result.stderr.decode(errors='replace').strip()[:200]}")

    os.unlink(tmp)
    return None

def audio_cover(source, size):
    ffmpeg = which("ffmpeg")
    if not ffmpeg:
        log(f"no ffmpeg found for {source}")
        return None

    fd, tmp = tempfile.mkstemp(prefix="doiz-athumb-", suffix=".png", dir=os.path.dirname(os.path.abspath(sys.argv[2])))
    os.close(fd)
    command = [ffmpeg, "-nostdin", "-y", "-loglevel", "error", "-i", source, "-an", "-sn",
               "-map", "0:v:0", "-frames:v", "1", "-vf", f"scale={size * 2}:-2", tmp]
    try:
        subprocess.run(command, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       timeout=30, check=False)
    except (OSError, subprocess.SubprocessError) as exc:
        log(f"ffmpeg cover failed on {source}: {exc}")

    if os.path.getsize(tmp) > 0:
        return tmp

    os.unlink(tmp)
    return None

OUTER = (4, 6, 60, 58)
MAT = 3
OUTER_RADIUS = 9

def accent():
    try:
        h, l, s = (float(v) for v in (STATE / "icon-accent").read_text().split()[:3])
        return h, l, s
    except (OSError, ValueError):
        return DEFAULT_ACCENT

def palette():
    sys.path.insert(0, str(CONFIG / "theme" / "scripts"))

    try:
        import doiz_icons

        return doiz_icons.colors(accent())
    except Exception:
        return {"dark": "#5e3069"}

def main():
    if len(sys.argv) != 4:
        return 2

    source, target, size = sys.argv[1], sys.argv[2], int(sys.argv[3])
    size = max(16, min(size, 1024))
    ss = 3 if size <= 256 else 2
    k = size * ss / 64.0
    c = palette()

    def box(rect, grow=0.0):
        return tuple(round((v + (-grow if i < 2 else grow)) * k) for i, v in enumerate(rect))

    inner_rect = tuple(v + (MAT if i < 2 else -MAT) for i, v in enumerate(OUTER))
    inner = box(inner_rect)
    window = (inner[2] - inner[0], inner[3] - inner[1])
    radius = round((OUTER_RADIUS - MAT) * k)

    frame = None
    if Path(source).suffix.lower() in VIDEO_EXT:
        frame = video_frame(source, size)
        if frame is None:
            return 1

    elif Path(source).suffix.lower() in AUDIO_EXT:
        frame = audio_cover(source, size)
        if frame is None:
            return 1

    with Image.open(frame or source) as image:
        image.draft("RGB", (size * 2, size * 2))
        image = ImageOps.exif_transpose(image).convert("RGBA")
        photo = ImageOps.fit(image, window, Image.LANCZOS)

    canvas = Image.new("RGBA", (size * ss, size * ss), (0, 0, 0, 0))

    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(box(OUTER), round(OUTER_RADIUS * k), fill=c["dark"])

    mask = Image.new("L", window, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, window[0] - 1, window[1] - 1), radius, fill=255)
    canvas.paste(photo, inner[:2], Image.composite(photo.getchannel("A"), Image.new("L", window, 0), mask))

    if frame:
        os.unlink(frame)

    result = canvas.resize((size, size), Image.LANCZOS)
    tmp = target + ".tmp.png"
    result.save(tmp, "PNG", optimize=True)
    os.replace(tmp, target)

    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"doiz-thumbnailer: {exc}", file=sys.stderr)
        sys.exit(1)
