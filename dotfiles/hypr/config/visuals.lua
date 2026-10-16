local visuals = {
    cursor = {
        inactive_timeout = 0,
        no_hardware_cursors = false,
        hide_on_key_press = false,
        hide_on_touch = true,
    },

    render = {
        direct_scanout = 0,
        expand_undersized_textures = true,
        send_content_type = true,
    },
}

hl.config(visuals)

return visuals
