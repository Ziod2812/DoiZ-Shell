local M = {}

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")

hl.env("XDG_CONFIG_HOME", os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config"))

hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")

hl.env("GDK_BACKEND", "wayland,x11")

hl.env("XCURSOR_THEME", "DoiZ-Cursor")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "DoiZ-Cursor")
hl.env("HYPRCURSOR_SIZE", "24")

return M
