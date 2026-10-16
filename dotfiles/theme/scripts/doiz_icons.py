
import colorsys
import re
from pathlib import Path

PLACES_DIR = "scalable/places"
MIME_DIR = "scalable/mimetypes"
APPS_DIR = "scalable/apps"
STATUS_DIR = "scalable/status"

TYPE_HUE_SHIFT = 0.0

NEUTRAL_SATURATION = 0.02

MONO = "JetBrainsMono Nerd Font, JetBrains Mono, DejaVu Sans Mono, monospace"

PAGE = "M13 9a6 6 0 0 1 6-6h17l15 15v37a6 6 0 0 1-6 6H19a6 6 0 0 1-6-6z"
FOLD = "M36 3l15 15H41a5 5 0 0 1-5-5z"
FOLDER_BACK = "M6 14a5 5 0 0 1 5-5h12.5a5 5 0 0 1 3.6 1.5L31 15h22a5 5 0 0 1 5 5v36H6z"

W = 'fill="none" stroke="@G" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"'
F = 'fill="@G" stroke="none"'
G = 'fill="@G" stroke="@G" stroke-linejoin="round"'

def hls(h, l, s):
    r, g, b = colorsys.hls_to_rgb(h % 1.0, max(0.0, min(1.0, l)), max(0.0, min(1.0, s)))

    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))

def dedupe_attrs(text):
    for attr in ("stroke-width", "stroke-opacity"):
        pattern = re.compile(attr + r'="[^"]*"((?:(?!>)[^<])*?)' + attr + "=")
        text = pattern.sub(lambda m: m.group(1).lstrip() and m.group(1) + attr + "=" or attr + "=", text)

    return text

def svg(c, body, defs=""):
    return dedupe_attrs(
        '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">'
        + (f"<defs>{defs}</defs>" if defs else "") + body.replace("@G", c["paper"]) + "</svg>\n"
    )

def band(c, label, y=42, on_page=True, x=6):
    if not label:
        return ""

    size = 9.4 if len(label) <= 3 else 7.8 if len(label) == 4 else 6.6
    width = max(22, len(label) * size * 0.62 + 11)
    fill, ink = (c["mid"], c["paper"]) if on_page else (c["light"], c["ink"])

    return (
        f'<rect x="{x}" y="{y}" width="{width:.1f}" height="14" rx="4.5" fill="{fill}"/>'
        f'<text x="{x + width / 2:.1f}" y="{y + 10.2}" text-anchor="middle" font-family="{MONO}" '
        f'font-weight="700" font-size="{size}" fill="{ink}">{label}</text>'
    )

FOLDER_GLYPHS = {
    "home": f'<path {W} d="M23 39l9-8 9 8M26 37v8h12v-8"/>',
    "download": f'<path {W} d="M32 30v12M26.5 37l5.5 5.5 5.5-5.5M25 47h14"/>',
    "documents": f'<path {W} d="M25 32h14M25 38h14M25 44h9"/>',
    "pictures": f'<path {F} d="M23 47l7-9 5 6 3-4 5 7z"/><circle {F} cx="38.5" cy="33.5" r="2.6"/>',
    "music": f'<path {W} d="M35 44V32l7-2v12"/><circle {F} cx="31.8" cy="44.5" r="3.4"/><circle {F} cx="38.8" cy="42.5" r="3.4"/>',
    "videos": f'<path {G} stroke-width="2" d="M28 32l13 7-13 7z"/>',
    "desktop": f'<rect {W} x="23" y="31" width="18" height="12" rx="2"/><path {W} d="M28 48h8"/>',
    "templates": f'<rect {W} x="24" y="31" width="7" height="7" rx="1.5"/><rect {W} x="33" y="31" width="7" height="7" rx="1.5"/><rect {W} x="24" y="40" width="16" height="7" rx="1.5"/>',
    "share": f'<circle {F} cx="25.5" cy="39" r="3"/><circle {F} cx="38.5" cy="32.5" r="3"/><circle {F} cx="38.5" cy="45.5" r="3"/><path {W} d="M28 37.5l8-4M28 40.5l8 4" stroke-width="2"/>',
    "star": f'<path {G} stroke-width="1.6" d="M32 31l2.6 5.4 5.9.8-4.3 4.1 1 5.9-5.2-2.8-5.2 2.8 1-5.9-4.3-4.1 5.9-.8z"/>',
    "network": f'<circle {W} cx="32" cy="39" r="8"/><path {W} d="M24 39h16M32 31c-4 4-4 12 0 16M32 31c4 4 4 12 0 16" stroke-width="2"/>',
    "config": f'<circle {W} cx="32" cy="39" r="3.5"/><path {W} d="M32 31v3M32 44v3M24 39h3M37 39h3M26.4 33.4l2.1 2.1M35.5 42.5l2.1 2.1M26.4 44.6l2.1-2.1M35.5 35.5l2.1-2.1" stroke-width="2.2"/>',
    "wallpaper": f'<path {F} d="M23 47l7-9 5 6 3-4 5 7z"/><circle {F} cx="25.5" cy="34.5" r="2.4"/>',
    "": "",
}

FOLDER_NAMES = {
    "": ["folder", "inode-directory", "folder-open", "folder-drag-accept", "folder-visiting", "gnome-fs-directory"],
    "home": ["user-home", "folder-home"],
    "download": ["folder-download", "folder-downloads"],
    "documents": ["folder-documents"],
    "pictures": ["folder-pictures", "folder-photos"],
    "music": ["folder-music"],
    "videos": ["folder-videos"],
    "desktop": ["user-desktop", "folder-desktop"],
    "templates": ["folder-templates"],
    "share": ["folder-publicshare", "folder-public"],
    "star": ["user-bookmarks", "folder-bookmarks", "folder-favorites"],
    "network": ["folder-remote", "folder-network"],
    "config": ["folder-config"],
    "wallpaper": ["folder-wallpapers"],
}

def folder_icon(c, glyph):
    return svg(
        c,
        f'<path d="{FOLDER_BACK}" fill="{c["dark"]}"/>'
        f'<rect x="6" y="20" width="52" height="36" rx="6" fill="{c["mid"]}"/>'
        f'<rect x="12" y="24" width="40" height="2.4" rx="1.2" fill="{c["light"]}" fill-opacity=".7"/>'
        + FOLDER_GLYPHS[glyph],
    )

def trash_icon(c, full):
    handle = (
        f'<path d="M25 12V8.5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2V12" fill="none" stroke="{c["light"]}" '
        'stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>' if full else ""
    )

    return svg(
        c,
        handle
        + f'<path d="M15 21h34l-2.4 31.5a5 5 0 0 1-5 4.5H22.4a5 5 0 0 1-5-4.5z" fill="{c["mid"]}"/>'
        f'<rect x="10" y="12.5" width="44" height="8" rx="4" fill="{c["light"]}"/>'
        f'<path d="M26 29v20M32 29v20M38 29v20" stroke="{c["dark"]}" stroke-opacity=".55" stroke-width="3" stroke-linecap="round"/>',
    )

def computer_icon(c):
    return svg(
        c,
        f'<path d="M26 44l-1.6 10h15.2L38 44z" fill="{c["dark"]}"/>'
        f'<rect x="18" y="53" width="28" height="4" rx="2" fill="{c["dark"]}"/>'
        f'<rect x="6" y="8" width="52" height="37" rx="7" fill="{c["mid"]}"/>'
        f'<rect x="10.5" y="12.5" width="43" height="28" rx="3.5" fill="{c["dark"]}"/>'
        f'<path d="M16 21h9M16 28h18" fill="none" stroke="{c["light"]}" stroke-width="2.2" stroke-linecap="round"/>',
    )

def drive_icon(c, usb=False):
    if usb:
        return svg(
            c,
            f'<rect x="6" y="20" width="42" height="24" rx="7" fill="{c["mid"]}"/>'
            f'<rect x="46" y="26" width="11" height="12" rx="2.5" fill="{c["dark"]}"/>'
            f'<circle {F} cx="16" cy="32" r="2.8"/>',
        )

    return svg(
        c,
        f'<rect x="5" y="19" width="54" height="26" rx="8" fill="{c["mid"]}"/>'
        f'<path d="M5 37h54a8 8 0 0 1-8 8H13a8 8 0 0 1-8-8z" fill="{c["dark"]}"/>'
        f'<rect x="13" y="26" width="22" height="3.4" rx="1.7" fill="@G" fill-opacity=".9"/>'
        f'<circle {F} cx="48" cy="41" r="2.4"/>',
    )

def clock_icon(c):
    return svg(
        c,
        f'<circle cx="32" cy="32" r="25" fill="{c["mid"]}"/>'
        f'<path {W} d="M32 17v15l10 6" stroke-width="3"/>',
    )

def globe_icon(c):
    return svg(
        c,
        f'<circle cx="32" cy="32" r="25" fill="{c["mid"]}"/>'
        f'<path d="M9 32h46M32 8c-10 8-10 40 0 48M32 8c10 8 10 40 0 48" fill="none" stroke="{c["light"]}" '
        'stroke-width="2.2" stroke-linecap="round"/>',
    )

def thunar_icon(c):
    return svg(
        c,
        f'<rect x="13" y="7" width="38" height="12" rx="4.5" fill="{c["dark"]}"/>'
        f'<rect x="9" y="14" width="46" height="12" rx="4.5" fill="{c["light"]}"/>'
        f'<rect x="6" y="22" width="52" height="34" rx="8" fill="{c["mid"]}"/>'
        f'<rect x="21" y="35" width="22" height="5.5" rx="2.75" fill="{c["paper"]}"/>',
    )

def question_icon(c):
    return svg(
        c,
        f'<circle cx="32" cy="32" r="25" fill="{c["mid"]}"/>'
        f'<path d="M24.5 25.5a7.5 7.5 0 1 1 11 6.6c-2.4 1.3-3.5 2.7-3.5 5.4" fill="none" stroke="{c["paper"]}" '
        'stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>'
        f'<circle cx="32" cy="46.5" r="2.8" fill="{c["paper"]}"/>',
    )

def info_icon(c):
    return svg(
        c,
        f'<circle cx="32" cy="32" r="25" fill="{c["mid"]}"/>'
        f'<circle cx="32" cy="20.5" r="3" fill="{c["paper"]}"/>'
        f'<path d="M32 29v17" fill="none" stroke="{c["paper"]}" stroke-width="4.4" stroke-linecap="round"/>',
    )

def lock_icon(c):
    return svg(
        c,
        f'<path d="M21 28v-6a11 11 0 0 1 22 0v6" fill="none" stroke="{c["light"]}" stroke-width="5.5" stroke-linecap="round"/>'
        f'<rect x="11" y="27" width="42" height="29" rx="8" fill="{c["mid"]}"/>'
        f'<circle cx="32" cy="39.5" r="4.2" fill="{c["paper"]}"/>'
        f'<path d="M32 42v7" fill="none" stroke="{c["paper"]}" stroke-width="4" stroke-linecap="round"/>',
    )

CODE_LABELS = {"SH", "PY", "LUA", "QML", "JS", "TS", "C", "C++", "H", "JAVA", "RS", "GO", "CSS", "HTML"}
_uid = [0]

def uid():
    _uid[0] += 1

    return f"g{_uid[0]}"

def page(c, content, label):
    return svg(
        c,
        f'<path d="{PAGE}" fill="{c["paper"]}"/>'
        f'<path d="{FOLD}" fill="{c["fold"]}"/>'
        + content
        + band(c, label),
    )

def doc_icon(c, label, lines=4, big=None):
    if big:
        content = (
            f'<text x="32" y="40" text-anchor="middle" font-family="{MONO}" '
            f'font-weight="700" font-size="19" fill="{c["mid"]}">{big}</text>'
        )

        return page(c, content, label)

    ys = [24, 30, 36, 42, 48][:lines]
    widths = [26, 26, 18, 26, 12]
    content = "".join(
        f'<rect x="19" y="{y}" width="{widths[i]}" height="3" rx="1.5" fill="{c["mid"] if i == 0 else c["rule"]}"/>'
        for i, y in enumerate(ys)
    )

    return page(c, content, label)

def code_icon(c, label):
    content = (
        f'<path d="M26 22l-6 6 6 6M38 22l6 6-6 6M34.5 20l-5 16" fill="none" stroke="{c["mid"]}" '
        'stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"/>'
    )

    return page(c, content, label)

def image_icon(c, label):
    g = uid()

    return svg(
        c,
        f'<rect x="4" y="8" width="56" height="48" rx="10" fill="{c["dark"]}"/>'
        f'<circle cx="43.5" cy="23" r="5" fill="{c["paper"]}"/>'
        f'<g clip-path="url(#{g})">'
        f'<path d="M4 50l17-19 11 12 7-7 21 18v10H4z" fill="{c["mid"]}"/>'
        f'<path d="M26 56l14-16 20 16z" fill="{c["light"]}"/></g>'
        + band(c, label, y=13, on_page=False, x=8.5),
        defs=f'<clipPath id="{g}"><rect x="4" y="8" width="56" height="48" rx="10"/></clipPath>',
    )

def video_icon(c):
    holes = "".join(
        f'<rect x="{x}" y="{y}" width="3.6" height="4.6" rx="1.4" fill="{c["mid"]}"/>'
        for x in (8, 52.4) for y in (17, 24.8, 32.6, 40.4)
    )

    return svg(
        c,
        f'<rect x="4" y="10" width="56" height="44" rx="10" fill="{c["dark"]}"/>'
        + holes
        + f'<circle cx="32" cy="32" r="12" fill="{c["mid"]}"/>'
        f'<path d="M29 26.5l9.5 5.5-9.5 5.5z" fill="@G"/>',
    )

def audio_icon(c):
    return svg(
        c,
        f'<rect x="5" y="5" width="54" height="54" rx="16" fill="{c["mid"]}"/>'
        f'<circle cx="32" cy="32" r="20" fill="{c["dark"]}" fill-opacity=".35"/>'
        f'<path {W} d="M27 40V23l14-4v17" stroke-width="3"/>'
        f'<circle {F} cx="23.5" cy="40.5" r="4.4"/><circle {F} cx="37.5" cy="36.5" r="4.4"/>',
    )

def archive_icon(c):
    return svg(
        c,
        f'<rect x="9" y="22" width="46" height="34" rx="6" fill="{c["mid"]}"/>'
        f'<rect x="5" y="9" width="54" height="16" rx="5" fill="{c["dark"]}"/>'
        f'<path d="M32 9v26" stroke="@G" stroke-width="3" stroke-dasharray="3.4 3.4"/>'
        f'<rect x="27.5" y="36" width="9" height="13" rx="3.5" fill="{c["light"]}"/>',
    )

def exec_icon(c):
    return svg(
        c,
        f'<rect x="5" y="5" width="54" height="54" rx="15" fill="{c["dark"]}"/>'
        f'<path d="M19 22l11 10-11 10" fill="none" stroke="{c["light"]}" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>'
        f'<path d="M34 44h13" stroke="{c["light"]}" stroke-width="4" stroke-linecap="round"/>',
    )

def disc_icon(c):
    return svg(
        c,
        f'<circle cx="32" cy="32" r="26" fill="{c["mid"]}"/>'
        f'<circle cx="32" cy="32" r="17" fill="none" stroke="{c["dark"]}" stroke-opacity=".4" stroke-width="2"/>'
        f'<circle cx="32" cy="32" r="8.5" fill="{c["dark"]}"/><circle cx="32" cy="32" r="3" fill="@G"/>'
        f'<path d="M12 22a22 22 0 0 1 17-11" fill="none" stroke="{c["light"]}" stroke-opacity=".7" stroke-width="3" stroke-linecap="round"/>',
    )

def db_icon(c):
    return svg(
        c,
        f'<path d="M10 16v32c0 5 9 9 22 9s22-4 22-9V16z" fill="{c["mid"]}"/>'
        f'<path d="M10 28c0 5 9 9 22 9s22-4 22-9M10 40c0 5 9 9 22 9s22-4 22-9" fill="none" stroke="{c["dark"]}" stroke-opacity=".5" stroke-width="2.4"/>'
        f'<ellipse cx="32" cy="16" rx="22" ry="9" fill="{c["light"]}"/>',
    )

def file_icon(c, glyph, label):
    if glyph == "image" or label == "SVG":
        return image_icon(c, label)
    if glyph == "video":
        return video_icon(c)
    if glyph == "audio":
        return audio_icon(c)
    if glyph == "archive":
        return archive_icon(c)
    if glyph == "exec":
        return exec_icon(c)
    if glyph == "disc":
        return disc_icon(c)
    if glyph == "db":
        return db_icon(c)
    if glyph == "font":
        return doc_icon(c, "", big="Aa")
    if glyph == "code" or label in CODE_LABELS:
        return code_icon(c, label)
    if glyph == "settings":
        return doc_icon(c, "INI", lines=3)

    return doc_icon(c, label, lines=5 if not label else 3)

FILE_TYPES = [
    (0.00, "lines", "", ["text-x-generic", "text-plain", "text-x-preview", "application-x-generic", "text-x-log", "text-x-readme"]),
    (0.00, "exec", "", ["application-x-executable", "application-x-shellscript-terminal", "application-x-sharedlib"]),
    (0.12, None, "SH", ["application-x-shellscript", "application-x-sh", "text-x-script", "text-x-shellscript", "text-x-sh"]),
    (0.30, None, "PY", ["text-x-python", "text-x-python3", "application-x-python-bytecode"]),
    (-0.12, None, "LUA", ["text-x-lua", "application-x-lua"]),
    (0.06, None, "QML", ["text-x-qml", "application-x-qml", "text-x-qml-project"]),
    (0.16, None, "JS", ["text-javascript", "application-javascript", "text-x-javascript", "application-x-javascript"]),
    (-0.06, None, "TS", ["text-x-typescript", "application-x-typescript", "video-vnd.trolltech.linguist", "text-vnd.trolltech.linguist", "text-vnd.qt.linguist", "application-x-linguist"]),
    (0.18, None, "JSON", ["application-json", "application-ld+json", "text-x-json"]),
    (-0.02, None, "YML", ["application-x-yaml", "text-x-yaml", "application-yaml"]),
    (0.22, None, "TOML", ["application-toml", "text-x-toml"]),
    (0.00, "settings", "", ["text-x-ini", "text-x-conf", "text-x-config", "application-x-desktop", "text-x-desktop", "application-x-theme"]),
    (-0.18, None, "MD", ["text-markdown", "text-x-markdown", "text-x-readme-md"]),
    (-0.08, None, "HTML", ["text-html", "application-xhtml+xml", "text-xml", "application-xml"]),
    (0.04, None, "CSS", ["text-css", "text-x-scss", "text-x-sass"]),
    (0.14, None, "C", ["text-x-csrc", "text-x-c"]),
    (0.14, None, "C++", ["text-x-c++src", "text-x-cpp"]),
    (0.14, None, "H", ["text-x-chdr", "text-x-c++hdr"]),
    (0.26, None, "JAVA", ["text-x-java", "application-x-java", "application-x-java-archive"]),
    (0.08, None, "RS", ["text-rust", "text-x-rust"]),
    (-0.10, None, "GO", ["text-x-go"]),
    (0.20, None, "SQL", ["text-x-sql", "application-sql"]),
    (0.00, "code", "", ["text-x-source", "text-x-makefile", "text-x-cmake", "text-x-diff", "text-x-patch", "text-x-php", "text-x-ruby", "text-x-perl"]),
    (0.00, "db", "", ["application-x-sqlite3", "application-vnd.sqlite3", "application-x-sqlite2"]),
    (0.20, None, "PDF", ["application-pdf", "application-x-pdf", "application-postscript"]),
    (-0.20, None, "DOC", ["x-office-document", "application-msword", "application-vnd.openxmlformats-officedocument.wordprocessingml.document", "application-vnd.oasis.opendocument.text", "application-rtf", "text-rtf"]),
    (0.10, None, "XLS", ["x-office-spreadsheet", "application-vnd.ms-excel", "application-vnd.openxmlformats-officedocument.spreadsheetml.sheet", "application-vnd.oasis.opendocument.spreadsheet", "text-csv"]),
    (0.26, None, "PPT", ["x-office-presentation", "application-vnd.ms-powerpoint", "application-vnd.openxmlformats-officedocument.presentationml.presentation", "application-vnd.oasis.opendocument.presentation"]),
    (-0.12, None, "EPUB", ["application-epub+zip", "application-x-mobipocket-ebook"]),
    (-0.10, "image", "", ["image-x-generic", "image-png", "image-jpeg", "image-gif", "image-webp", "image-bmp", "image-tiff", "image-avif", "image-heif", "image-x-icon", "image-vnd.microsoft.icon", "image-x-xcf", "image-x-psd", "image-vnd.adobe.photoshop"]),
    (-0.14, None, "SVG", ["image-svg+xml", "image-svg+xml-compressed", "image-x-svg+xml"]),
    (0.18, "audio", "", ["audio-x-generic", "audio-mpeg", "audio-flac", "audio-ogg", "audio-x-wav", "audio-x-vorbis+ogg", "audio-aac", "audio-mp4", "audio-x-opus+ogg", "audio-midi", "audio-x-mp3", "audio-x-mpeg", "audio-x-flac", "audio-x-ogg", "audio-x-m4a", "audio-x-ms-wma", "audio-x-aiff", "audio-x-matroska", "audio-webm", "audio-opus", "audio-x-ape", "audio-x-mpegurl", "audio-x-scpls", "audio-x-vorbis", "audio-x-speex", "audio-x-wavpack", "audio-amr", "audio-ac3"]),
    (-0.20, "video", "", ["video-x-generic", "video-mp4", "video-x-matroska", "video-webm", "video-quicktime", "video-x-msvideo", "video-mpeg", "video-ogg", "video-x-flv", "video-3gpp"]),
    (0.10, "archive", "", ["package-x-generic", "application-zip", "application-x-tar", "application-x-compressed-tar", "application-gzip", "application-x-gzip", "application-x-7z-compressed", "application-vnd.rar", "application-x-rar", "application-x-xz", "application-x-xz-compressed-tar", "application-x-bzip", "application-x-bzip-compressed-tar", "application-zstd", "application-x-zstd-compressed-tar", "application-x-lzma", "application-x-cpio", "application-x-archive", "application-x-compressed", "application-x-zip", "application-x-zip-compressed", "application-vnd.debian.binary-package", "application-x-rpm", "application-x-pacman-package", "application-x-java-archive"]),
    (0.00, "disc", "", ["application-x-cd-image", "application-x-iso9660-image", "application-x-raw-disk-image", "application-x-cdimage", "application-vnd.efi.iso", "application-x-qemu-disk", "application-x-virtualbox-vdi"]),
    (0.24, None, "APP", ["application-vnd.appimage", "application-x-appimage", "application-x-iso9660-appimage", "application-vnd.flatpak", "application-vnd.flatpak.ref"]),
    (-0.06, "font", "", ["font-x-generic", "application-x-font-ttf", "application-x-font-otf", "font-ttf", "font-otf", "font-woff", "font-woff2", "application-font-woff", "application-x-font-pcf"]),
    (0.00, None, "BIN", ["application-octet-stream", "application-x-object", "application-x-core", "application-x-firmware"]),
    (0.12, None, "LOG", ["text-x-log-file"]),
    (-0.04, None, "KEY", ["application-pgp-keys", "application-pgp-signature", "application-x-pem-file", "application-pkcs12", "application-x-x509-ca-cert", "application-pkix-cert+pem"]),
    (0.30, None, "TORR", ["application-x-bittorrent"]),
    (0.06, None, "PKG", ["application-x-ms-dos-executable", "application-vnd.microsoft.portable-executable", "application-x-msi", "application-x-ms-shortcut"]),
]

def _words(stem):
    return set(re.split(r"[-_.+]+", stem.lower()))

ARCHIVE_WORDS = {
    "zip", "tar", "gzip", "gz", "bzip", "bzip2", "xz", "7z", "rar", "lzma", "cpio", "archive", "compressed", "rpm",
    "deb", "cab", "jar", "lha", "lzh", "zstd", "arj", "ace", "squashfs", "package", "pkg", "ar", "tgz", "tbz",
    "txz", "zoo", "stuffit", "alz", "lrzip", "lzip", "lzop", "compress", "pacman", "snap", "flatpak", "appimage",
}
DISC_WORDS = {
    "iso9660", "cd", "cdimage", "disc", "disk", "dvd", "vmdk", "vdi", "vhd", "qcow", "qcow2", "floppy", "rom", "wim", "iso",
}
DB_WORDS = {"sqlite", "sqlite2", "sqlite3", "db", "database", "mdb", "dbf", "accdb", "access", "kexi", "dbase"}
EXEC_WORDS = {"executable", "sharedlib", "exe", "msdos", "dos", "bat", "batch", "msi", "shortcut", "object"}
SHEET_WORDS = {"spreadsheet", "calc", "xls", "xlsx", "ods", "csv", "tsv", "tab", "gnumeric", "numbers"}
SLIDE_WORDS = {"presentation", "impress", "ppt", "pptx", "odp", "keynote", "slideshow"}
DOC_WORDS = {"document", "writer", "word", "doc", "docx", "odt", "rtf", "wordprocessing", "pages", "abiword", "richtext"}
BOOK_WORDS = {"epub", "ebook", "mobi", "kindle", "djvu", "cbz", "cbr", "fb2", "comic"}
PLAIN_WORDS = {
    "plain", "enriched", "troff", "calendar", "vcard", "vcalendar", "tab", "separated", "values", "markdown", "log",
    "readme", "authors", "changelog", "copying", "credits", "install", "news", "todo", "preview", "asciidoc", "org",
}
CODE_WORDS = {
    "src", "source", "script", "hdr", "java", "python", "python3", "perl", "ruby", "php", "lua", "rust", "go", "csharp",
    "fsharp", "swift", "kotlin", "scala", "haskell", "lisp", "asm", "sql", "shell", "sh", "bash", "javascript",
    "typescript", "coffeescript", "julia", "r", "ocaml", "tcl", "vala", "vb", "vbscript", "makefile", "cmake", "patch",
    "diff", "qml", "css", "scss", "sass", "html", "xml", "xhtml", "json", "yaml", "toml", "ini", "conf", "config",
    "latex", "tex", "bibtex", "dart", "elixir", "erlang", "fortran", "groovy", "lisp", "matlab", "pascal", "prolog",
    "cobol", "crystal", "d", "arduino", "typst", "sgml", "rdf", "n3", "turtle", "wml", "wmlscript",
}

def classify_mime(stem):
    s = stem.lower()
    w = _words(s)

    if s.startswith("audio-"):
        return ("audio", "")
    if s.startswith("video-"):
        return ("video", "")
    if s.startswith("image-"):
        return ("image", "")
    if s.startswith("font-") or "font" in w:
        return ("font", "")
    if w & ARCHIVE_WORDS or "compress" in s:
        return ("archive", "")
    if w & DISC_WORDS:
        return ("disc", "")
    if w & DB_WORDS:
        return ("db", "")
    if w & EXEC_WORDS:
        return ("exec", "")
    if w & SHEET_WORDS:
        return (None, "XLS")
    if w & SLIDE_WORDS:
        return (None, "PPT")
    if w & BOOK_WORDS:
        return (None, "EPUB")
    if "pdf" in w or "postscript" in w:
        return (None, "PDF")
    if w & DOC_WORDS:
        return (None, "DOC")
    if w & PLAIN_WORDS:
        return ("lines", "")
    if s.startswith(("text-", "application-x-")) and w & CODE_WORDS:
        return ("code", "")
    if s.startswith("text-"):
        return ("lines", "")

    return ("lines", "")

def colors(accent_hls):
    h, l, s = accent_hls
    neutral = s < NEUTRAL_SATURATION
    tint = 0.0 if neutral else 1.0
    s = 0.0 if neutral else max(0.36, min(0.62, s))
    l = max(0.58, min(0.68, l))

    return {
        "h": h,
        "l": l,
        "s": s,
        "dark": hls(h, 0.30, s * 0.9),
        "mid": hls(h, 0.50, s),
        "light": hls(h, 0.74, s * 0.8),
        "paper": hls(h, 0.95, 0.25 * tint),
        "fold": hls(h, 0.84, 0.25 * tint),
        "rule": hls(h, 0.84, 0.22 * tint),
        "ink": hls(h, 0.16, 0.40 * tint),
    }

def write(out, name, text):
    (out / f"{name}.svg").write_text(text, encoding="utf-8")

def build(target, accent_hls, source=None):
    target = Path(target)
    places = target / PLACES_DIR
    mimes = target / MIME_DIR
    places.mkdir(parents=True, exist_ok=True)
    mimes.mkdir(parents=True, exist_ok=True)
    apps = target / APPS_DIR
    status = target / STATUS_DIR
    apps.mkdir(parents=True, exist_ok=True)
    status.mkdir(parents=True, exist_ok=True)

    c = colors(accent_hls)

    for name in ("thunar", "org.xfce.thunar", "org.xfce.Thunar", "system-file-manager", "org.xfce.thunar-settings"):
        write(apps, name, thunar_icon(c))

    for name in ("help-browser", "help-contents", "help-faq", "system-help", "dialog-question"):
        write(status, name, question_icon(c))

    for name in ("help-about", "dialog-information"):
        write(status, name, info_icon(c))

    for name in ("dialog-password", "dialog-password-symbolic", "security-high", "security-medium", "security-low", "password-copy"):
        write(status, name, lock_icon(c))

    for glyph, names in FOLDER_NAMES.items():
        text = folder_icon(c, glyph)

        for name in names:
            write(places, name, text)

    write(places, "user-trash", trash_icon(c, False))
    write(places, "user-trash-full", trash_icon(c, True))
    write(places, "computer", computer_icon(c))
    write(places, "computer-laptop", computer_icon(c))

    for name in ("drive-harddisk", "drive-harddisk-system", "drive-multidisk", "drive-optical", "drive-harddisk-ieee1394"):
        write(places, name, drive_icon(c))

    for name in ("drive-removable-media", "drive-removable-media-usb", "media-removable", "media-flash"):
        write(places, name, drive_icon(c, True))

    for name in ("document-open-recent", "folder-recent", "view-history"):
        write(places, name, clock_icon(c))

    for name in ("network-workgroup", "network-server", "network-workgroup-symbolic-fallback"):
        write(places, name, globe_icon(c))

    for offset, glyph, label, names in FILE_TYPES:
        shade = c if not TYPE_HUE_SHIFT else colors((c["h"] + offset * TYPE_HUE_SHIFT, c["l"], c["s"]))
        text = file_icon(shade, glyph, label)

        for name in names:
            write(mimes, name, text)

    if source is not None:
        drawn = {}
        have = {p.stem for p in mimes.glob("*.svg")}

        for mime_dir in sorted(Path(source).glob("*/mimetypes")):
            for entry in sorted(mime_dir.iterdir()):
                if entry.suffix != ".svg" or entry.stem in have or "symbolic" in entry.stem:
                    continue

                kind = classify_mime(entry.stem)

                if kind not in drawn:
                    drawn[kind] = file_icon(c, *kind)

                write(mimes, entry.stem, drawn[kind])
                have.add(entry.stem)

    common = {"Size": "64", "MinSize": "16", "MaxSize": "512", "Type": "Scalable"}

    return [
        (PLACES_DIR, dict(common, Context="Places")),
        (MIME_DIR, dict(common, Context="MimeTypes")),
        (APPS_DIR, dict(common, Context="Applications")),
        (STATUS_DIR, dict(common, Context="Status")),
    ]
