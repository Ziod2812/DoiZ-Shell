#!/usr/bin/env python3
import hashlib
import os
import sys
from pathlib import Path

from PIL import Image

Image.MAX_IMAGE_PIXELS = None

IMAGE_EXT = {".jpg", ".jpeg", ".png", ".webp", ".gif"}
VIDEO_EXT = {".mp4", ".webm", ".mkv", ".mov", ".avi"}

CACHE_HOME = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
CACHE_DIR = CACHE_HOME / "doiz"
THUMB_DIR = CACHE_DIR / "video-thumbs"
CACHE_FILE = CACHE_DIR / "wallpaper-colors.tsv"
CACHE_VERSION = "v1"

MIN_SHARE = 0.22
FALLBACK_SHARE = 0.08
MAX_TAGS = 2


def file_key(path, mtime):
    raw = f"{path}\n{int(mtime)}"
    return hashlib.md5(raw.encode()).hexdigest()


def hue_name(hue):
    if hue < 15 or hue >= 345:
        return "red"
    if hue < 45:
        return "orange"
    if hue < 70:
        return "yellow"
    if hue < 165:
        return "green"
    if hue < 195:
        return "cyan"
    if hue < 255:
        return "blue"
    if hue < 290:
        return "purple"
    return "pink"


def bucket(h, s, v):
    hue = h * 360.0 / 255.0
    sat = s / 255.0
    val = v / 255.0
    if val < 0.10 or (sat < 0.25 and val < 0.28):
        return "black"
    if sat < 0.16 and val > 0.85:
        return "white"
    if sat < 0.10:
        return "white" if val > 0.78 else "gray"
    return hue_name(hue)


def classify(path):
    with Image.open(path) as img:
        img.draft("RGB", (160, 160))
        img = img.convert("RGB")
        img.thumbnail((64, 64))
        data = img.convert("HSV").tobytes()

    counts = {}
    total = 0
    for i in range(0, len(data) - 2, 3):
        name = bucket(data[i], data[i + 1], data[i + 2])
        counts[name] = counts.get(name, 0) + 1
        total += 1

    if total == 0:
        return "gray"

    ranked = sorted(counts.items(), key=lambda item: item[1], reverse=True)
    tags = [
        name
        for name, count in ranked
        if name != "gray" and count / total >= MIN_SHARE
    ][:MAX_TAGS]

    if not tags:
        for name, count in ranked:
            if name != "gray" and count / total >= FALLBACK_SHARE:
                tags = [name]
                break

    return ",".join(tags) if tags else "gray"


def load_cache():
    cache = {}
    try:
        with open(CACHE_FILE, encoding="utf-8") as handle:
            for line in handle:
                parts = line.rstrip("\n").split("\t")
                if len(parts) == 3 and parts[0] == CACHE_VERSION:
                    cache[parts[1]] = parts[2]
    except OSError:
        pass
    return cache


def list_files(root):
    found = []
    for base, _dirs, names in os.walk(root):
        for name in names:
            ext = os.path.splitext(name)[1].lower()
            if ext in IMAGE_EXT or ext in VIDEO_EXT:
                found.append(os.path.join(base, name))
    found.sort(key=lambda value: value.lower())
    return found


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else ""
    if not root or not os.path.isdir(root):
        return 0

    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cache = load_cache()

    try:
        os.nice(10)
    except OSError:
        pass

    with open(CACHE_FILE, "a", encoding="utf-8") as out:
        for path in list_files(root):
            try:
                mtime = os.stat(path).st_mtime
            except OSError:
                continue

            key = file_key(path, mtime)
            ext = os.path.splitext(path)[1].lower()
            is_video = ext in VIDEO_EXT

            if key in cache:
                print(f"{path}\t{cache[key]}", flush=True)
                continue

            source = path
            if is_video:
                source = str(THUMB_DIR / f"{key}.jpg")
                if not os.path.isfile(source):
                    continue

            try:
                tags = classify(source)
            except Exception:
                continue

            cache[key] = tags
            out.write(f"{CACHE_VERSION}\t{key}\t{tags}\n")
            out.flush()
            print(f"{path}\t{tags}", flush=True)

    return 0


if __name__ == "__main__":
    sys.exit(main())
