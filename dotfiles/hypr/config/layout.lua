local function load_border()
    local path = os.getenv("HOME") .. "/.config/hypr/local/theme-border.lua"
    local ok, border = pcall(dofile, path)

    if ok and type(border) == "table" then
        return border
    end

    return {}
end

local border = load_border()

local layout = {
    general = {
        layout = "dwindle",
        allow_tearing = false,
        border_size = 3,
        col = {
            active_border = border.active or "rgba(96b0c3de)",
            inactive_border = border.inactive or "rgba(96b0c3de)",
        },
        resize_on_border = true,
        extend_border_grab_area = 15,
        hover_icon_on_border = true,
    },

    dwindle = {
        preserve_split = true,
        smart_split = false,
        smart_resizing = true,
        force_split = 2,
    },

    master = {
        new_status = "master",
        new_on_top = false,
        mfact = 0.5,
        orientation = "left",
        slave_count_for_center_master = 2,
    },
}

hl.config(layout)

return layout
