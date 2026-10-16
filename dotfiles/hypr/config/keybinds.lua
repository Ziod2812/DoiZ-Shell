local programs = require("config.programs")

local scriptsDir = "$HOME/.config/hypr/scripts/infinite-desktop"
local repeating = { repeating = true }
local mouse = { mouse = true }
local locked = { locked = true }
local locked_repeating = { locked = true, repeating = true }

local function bind(key, action, flags)
    if key and key ~= "" then hl.bind(key, action, flags) end
end

local function exec_script(script, arg)
    local cmd = "python3 " .. scriptsDir .. "/" .. script
    if arg then cmd = cmd .. " " .. arg end
    return hl.dsp.exec_cmd(cmd)
end

local function workspace_action(workspace)
    return hl.dsp.focus({ workspace = workspace })
end

local function move_workspace(workspace)
    return hl.dsp.window.move({ workspace = workspace })
end

bind("SUPER + SUPER_L", hl.dsp.exec_cmd("pgrep -f '(qs|quickshell) .*-c wsoverview' >/dev/null || " .. programs.launcher), { release = true })

for i = 1, 10 do
    local key = i % 10
    bind("SUPER + " .. key, workspace_action(tostring(i)))
    bind("SUPER + ALT + " .. key, move_workspace(tostring(i)))
    bind("CTRL + SUPER + " .. key, workspace_action(tostring(i * 10)))
    bind("CTRL + SUPER + ALT + " .. key, move_workspace(tostring(i * 10)))
end

bind("SUPER + mouse_down", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/doiz-wsoverview.sh wheel-down"))
bind("SUPER + mouse_up", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/doiz-wsoverview.sh wheel-up"))
bind("SUPER + SHIFT + mouse_down", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/doiz-wsoverview.sh wheel-down"))
bind("SUPER + SHIFT + mouse_up", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/doiz-wsoverview.sh wheel-up"))
bind("SUPER + ALT + mouse_down", function() end)
bind("SUPER + ALT + mouse_up", function() end)
bind("SUPER + ALT + A", function() end)

bind("SUPER + Tab", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/doiz-wsoverview.sh next"))
bind("SUPER + SHIFT + Tab", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/doiz-wsoverview.sh prev"))

bind("ALT + Tab", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/doiz-windowtab.sh next"))
bind("ALT + SHIFT + Tab", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/doiz-windowtab.sh prev"))

bind("SUPER + S", hl.dsp.workspace.toggle_special("special"))
bind("SUPER + ALT + S", hl.dsp.window.move({ workspace = "special:special" }))
bind("CTRL + SUPER + SHIFT + Down", hl.dsp.window.move({ workspace = "previous" }))

bind("SUPER + D", exec_script("floating_tile_toggle.py"))
bind("SUPER + SHIFT + D", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/toggle-infinite-desktop"))
bind("SUPER + SHIFT + A", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/toggle-auto-arrange-grid"))
bind("SUPER + SHIFT + B", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/blackhole"))
bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/doiz-wallpaperpicker.sh"))
bind("SUPER + ALT + W", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/wallpaper-random.sh"))
bind("SUPER + CTRL + SHIFT + B", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/blackhole --dry"))
bind("SUPER + ALT + B", hl.dsp.exec_cmd("qs -c effects ipc call effects toggle || qs -c effects -n &"))
for _, direction in ipairs({ "left", "right", "up", "down" }) do
    bind("SUPER + " .. direction, exec_script("navigate_windows.py", direction))
    bind("SUPER + SHIFT + " .. direction, exec_script("move_window.py", direction), repeating)
    bind("SUPER + ALT + " .. direction, exec_script("move_window_tiled.py", direction), repeating)
    bind("SUPER + CTRL + ALT + " .. direction, exec_script("resize_window.py", direction), repeating)
end

bind("SUPER + mouse:272", hl.dsp.window.drag(), mouse)
bind("SUPER + SHIFT + mouse:272", function() end)
bind("SUPER + X", hl.dsp.window.resize(), mouse)
bind("SUPER + ALT + Space", hl.dsp.window.float())
bind("SUPER + Q", hl.dsp.exec_cmd("pgrep -f '(qs|quickshell) .*-c screenshot' >/dev/null && qs -c screenshot ipc call screenshot discard || hyprctl dispatch 'hl.dsp.window.close()'"))
bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
bind("SUPER + ALT + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
bind("CTRL + SUPER + Backslash", hl.dsp.window.center())
bind("SUPER + P", hl.dsp.window.pin())
bind("SUPER + T", hl.dsp.exec_cmd(programs.terminal))
bind("SUPER + W", hl.dsp.exec_cmd(programs.browser))
bind("SUPER + E", hl.dsp.exec_cmd(programs.fileManager))
bind("SUPER + N", hl.dsp.exec_cmd(programs.notification .. " ipc call controlcenter toggle"))
bind("SUPER + I", hl.dsp.exec_cmd(programs.settings))

bind("SUPER + V", hl.dsp.exec_cmd(programs.clipboard))
bind("SUPER + ALT + V", hl.dsp.exec_cmd("cliphist wipe"))

bind("SUPER + H", hl.dsp.exec_cmd(programs.keybinds))
bind("SUPER + M", hl.dsp.exec_cmd(programs.spotify))
bind("SUPER + C", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/doiz-cavadesk"))
bind("PRINT", hl.dsp.exec_cmd(programs.screenshot))
bind("SUPER + SHIFT + S", hl.dsp.exec_cmd(programs.screenshotArea))
bind("CTRL + ALT + R", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/record.sh toggle"))
bind("SUPER + ALT + R", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/record.sh audio"))
bind("SUPER + SHIFT + ALT + R", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/record.sh region"))
bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd(programs.terminal .. " -e $HOME/.config/btop/run-btop"))
bind("SUPER + L", hl.dsp.exec_cmd(programs.lock))
bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))

bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), locked_repeating)
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), locked_repeating)
bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), locked)
bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), locked)
bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), locked_repeating)
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), locked_repeating)
bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), locked)
bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), locked)
bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), locked)
bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), locked)
