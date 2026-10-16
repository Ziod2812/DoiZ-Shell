# DoiZ-Cursor

A cursor set in the DoiZ style, built from the Bibata Modern shapes (GPL-3.0, see `LICENSE`). The SVG sources are in `svg/original` and `svg/modern`.

- Cursor body: `background`, outline: `foreground` from `theme/theme.conf`.
- Badges use `accent_alt`, `blue`, `green`, `red` and `yellow`.
- The four corner resize cursors and the four spokes of the busy ring (`wait`, `left_ptr_watch`) each get their own color: when the wallpaper changes, `build.py --apply` analyzes 8 colors of the image (`colorthief`), brightens and saturates them like `boost_color`, and picks the 4 with the most different hues. The prebuilt theme uses `cyan`, `red`, `green` and `yellow`.
- The prebuilt theme lives in `DoiZ-Cursor/`; `install.sh` copies it into `~/.local/share/icons/`.

## Recoloring from the wallpaper

Every time `apply-theme.py` changes the wallpaper or the light/dark mode, it runs `build.py --apply` in the background:

1. Reads the new palette from `theme.conf` and the image in `~/.local/state/doiz/current-wallpaper`, redraws the SVGs and writes the XCursor files (about 2 seconds, no `clickgen` needed).
2. Writes to `DoiZ-Cursor-A` or `DoiZ-Cursor-B` alternately so running applications pick up the new theme, and also updates `DoiZ-Cursor` for the next login session.
3. Updates the `gtk-3.0`/`gtk-4.0` settings and gsettings, refreshes `~/.local/share/icons/default` and runs `hyprctl setcursor`.

The size comes from `XCURSOR_SIZE` (default 24).

## Manual build

```sh
pacman -S python-cairosvg python-pillow
~/.config/cursor/build.py --install
~/.config/cursor/build.py --install --fill 1A1D33 --outline D6DAED --accent 6A85CC
~/.config/cursor/build.py --apply
~/.config/cursor/build.py --install --wallpaper /path/to/image.jpg
~/.config/cursor/build.py --install --shape soft
~/.config/cursor/build.py --install --shape original
```

There are three shapes: `modern` (default, rounded), `soft` (Original with slightly rounded corners) and `original` (sharp corners). The rounding of `soft` is set with `DOIZ_CURSOR_ROUND` (default 4.5, higher is rounder).

Set `DOIZ_CURSOR_SHAPE=soft` (or `original`) to change the default shape, including when colors follow the wallpaper automatically.
