local function overrides()
    local data = {}
    local f = io.open((os.getenv("HOME") or "") .. "/.config/mycfg/doiz-settings.env", "r")

    if f then
        for line in f:lines() do
            local k, v = line:match("^([%w_]+)=(.*)$")

            if k then
                data[k] = v
            end
        end

        f:close()
    end

    return data
end

local user = overrides()

local programs = {
    terminal = user.terminal or "kitty",
    browser = user.browser or "helium-browser",
    fileManager = user.file_manager or "thunar",
    spotify = "sh -c 'command -v spotify >/dev/null && exec spotify || exec spotify-launcher'",
    launcher = "qs -c launcher ipc call launcher toggle || qs -c launcher &",
    keybinds = "qs -c keybinds ipc call keybinds toggle || qs -c keybinds -n &",
    clipboard = "qs -c clipboard ipc call clipboard toggle || qs -c clipboard -n &",
    lock = "$HOME/.config/hypr/scripts/lock.sh",
    idle = "hypridle",
    screenshot = "$HOME/.config/hypr/scripts/screenshot.sh",
    screenshotArea = "$HOME/.config/hypr/scripts/screenshot-area.sh",
    wallpaper = "awww",
    settings = "qs -c settings ipc call settings toggle || qs -c settings -n &",
    notification = "$HOME/.config/hypr/scripts/doiz-controlcenter",
}

return programs