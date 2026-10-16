local misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    force_default_wallpaper = 0,

    vrr = 0,

    focus_on_activate = true,
    animate_manual_resizes = false,
    animate_mouse_windowdragging = false,

    allow_session_lock_restore = true,

    enable_swallow = false,
    swallow_regex = "",

    on_focus_under_fullscreen = 2,
    exit_window_retains_fullscreen = true,

    initial_workspace_tracking = 0,

    middle_click_paste = true,
    render_unfocused_fps = 15,

    background_color = "rgb(1e1e2e)",

}

hl.config({ misc = misc })

return misc
