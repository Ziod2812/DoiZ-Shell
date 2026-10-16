local input = {
    kb_layout = "us",
    kb_variant = "",
    kb_model = "",
    kb_options = "",
    kb_rules = "",

    numlock_by_default = false,
    resolve_binds_by_sym = false,

    follow_mouse = 1,
    mouse_refocus = true,
    float_switch_override_focus = 0,
    special_fallthrough = true,

    sensitivity = 0,
    scroll_factor = 2.5,
    accel_profile = "adaptive",
    force_no_accel = false,

    touchpad = {
        disable_while_typing = true,
        natural_scroll = true,
        tap_to_click = true,
        tap_and_drag = true,
        drag_lock = false,
        middle_button_emulation = false,
        clickfinger_behavior = false,
        scroll_factor = 1,
    },
}

local tablet = {
    transform = 0,
    output = "",
}

local touchdevice = {
    transform = 0,
    output = "",
}

hl.config({ input = input })

if tablet.output ~= "" then
    hl.device({
        name = "tablet",
        output = tablet.output,
        transform = tablet.transform,
    })
end

if touchdevice.output ~= "" then
    hl.device({
        name = "touchdevice",
        output = touchdevice.output,
        transform = touchdevice.transform,
    })
end

return input
