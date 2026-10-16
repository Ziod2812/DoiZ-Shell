local decoration = {
    rounding = 4,

    active_opacity = 1.0,
    inactive_opacity = 1.0,
    fullscreen_opacity = 1.0,

    shadow = {
        enabled = false,
        range = 4,
        render_power = 3,
        sharp = false,
        scale = 1.0,
    },

    blur = {
        enabled = true,
        size = 6,
        passes = 2,
        noise = 0.02,
        brightness = 0.9,
        vibrancy = 0.15,
        xray = true,
        new_optimizations = true,
        ignore_opacity = true,
        popups = true,
        popups_ignorealpha = 0.2,
    },

    dim_inactive = false,
    dim_strength = 0.1,
}

hl.config({ decoration = decoration })

return decoration
