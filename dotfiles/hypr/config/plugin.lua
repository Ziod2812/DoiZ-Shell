
local plugin = {
    enabled = false,
}

if not plugin.enabled then
    return plugin
end

hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpm reload -n && hyprctl reload")
end)

pcall(function()
    hl.config({
        plugin = {
            hyprexpo = {
                columns = 1,
                gap_size = 18,
                bg_col = "rgb(1b1b1b)",
                workspace_method = "center current",
                skip_empty = false,
            },
        },
    })
end)

hl.bind("SUPER + G", function()
    hl.plugin.hyprexpo.expo("toggle")
end)

return plugin
