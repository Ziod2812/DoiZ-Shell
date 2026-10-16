local custom = {
    terminal = nil,
    browser = nil,
    file_manager = nil,
    launcher = nil,

    monitor = nil,
    scale = nil,

    cursor_size = nil,
    cursor_theme = nil,

    extra_binds = {},
    extra_window_rules = {},
    extra_layer_rules = {},
}


local function doiz_settings()
    local data = {}
    local f = io.open((os.getenv("HOME") or "") .. "/.config/mycfg/doiz-settings.env", "r")

    if not f then
        return data
    end

    for line in f:lines() do
        local k, v = line:match("^([%w_]+)=(.*)$")

        if k then
            data[k] = v
        end
    end

    f:close()

    return data
end

local function apply_settings()
    local s = doiz_settings()
    local n = function(key) return tonumber(s[key]) end
    local config = {}

    if n("gaps_in") or n("gaps_out") or n("border_size") then
        config.general = { gaps_in = n("gaps_in"), gaps_out = n("gaps_out"), border_size = n("border_size") }
    end

    config.decoration = {
        rounding = n("rounding"),
        inactive_opacity = n("inactive_opacity") and n("inactive_opacity") / 100 or nil,
        blur = s.blur and { enabled = s.blur == "1" } or nil,
        shadow = s.shadow and { enabled = s.shadow == "1" } or nil,
    }

    config.input = {
        sensitivity = n("sensitivity") and n("sensitivity") / 100 or nil,
        kb_layout = s.kb_layout,
        follow_mouse = n("follow_mouse"),
        numlock_by_default = s.numlock and s.numlock == "1" or nil,
        touchpad = {
            natural_scroll = s.natural_scroll and s.natural_scroll == "1" or nil,
            tap_to_click = s.tap_to_click and s.tap_to_click == "1" or nil,
        },
    }

    if s.animations then
        config.animations = { enabled = s.animations == "1" }
    end

    hl.config(config)

    local keys = loadfile((os.getenv("HOME") or "") .. "/.config/mycfg/custom-keys.lua")

    if keys then
        pcall(keys)
    end
end

function custom.apply()
    pcall(apply_settings)

    if custom.monitor and custom.scale then
        hl.monitor({
            output = custom.monitor,
            mode = "preferred",
            position = "auto",
            scale = custom.scale,
        })
    end

    if custom.cursor_size then
        hl.config({
            cursor = {
                size = custom.cursor_size,
            },
        })
    end

    if custom.cursor_theme then
        hl.env("HYPRCURSOR_THEME", custom.cursor_theme)
        hl.env("XCURSOR_THEME", custom.cursor_theme)
    end

    for _, item in ipairs(custom.extra_binds) do
        if item.key and item.action then
            hl.bind(
                item.key,
                item.action,
                item.flags
            )
        end
    end

    for _, item in ipairs(custom.extra_window_rules) do
        if item.rule then
            hl.window_rule(item.rule)
        end
    end

    for _, item in ipairs(custom.extra_layer_rules) do
        if item.rule then
            hl.layer_rule(item.rule)
        end
    end
end

return custom
