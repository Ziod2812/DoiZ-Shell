hl.window_rule({
    match = { class = "^(pavucontrol|nm-connection-editor|blueman-manager)$" },
    float = true,
    center = true,
    size = { 900, 600 },
})

hl.window_rule({
    match = { class = "^(zenity|Zenity|org\\.gnome\\.Zenity|kdialog)$" },
    float = true,
    center = true,
    size = { 900, 600 },
})

hl.window_rule({
    match = { title = "^(Picture-in-Picture|Open File|Save File)$" },
    float = true,
})

hl.window_rule({
    match = { class = "^(Alacritty|kitty)$" },
    opacity = "0.96 override 0.96 override",
})

hl.window_rule({
    match = { class = "^(thunar|Thunar)$" },
    opacity = "1.0 override 1.0 override",
    rounding = 12,
    border_size = 0,
})

hl.window_rule({
    match = {
        class = "^(thunar|Thunar)$",
        title = "^(Emptying|Copying|Moving|Deleting|Trashing|Restoring|Linking|Creating|Applying|Preparing|Collecting|Transferring|Unlinking|Calculating|Paste|Operation).*",
    },
    float = true,
    center = true,
    size = { 520, 170 },
})

hl.window_rule({
    match = { class = "^(polkit-gnome-authentication-agent-1|org\\.kde\\.polkit-kde-authentication-agent-1|polkit-kde-authentication-agent-1)$" },
    float = true,
    center = true,
    opacity = "1.0 override 1.0 override",
    rounding = 12,
    border_size = 0,
})

hl.window_rule({
    match = { class = ".*" },
    suppress_event = "maximize",
    no_max_size = true,
})
