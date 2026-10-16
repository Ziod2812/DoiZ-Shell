local M = {}

M.env = require("config.env")
M.programs = require("config.programs")
M.monitors = require("config.monitors")
M.workspaces = require("config.workspaces")
M.input = require("config.input")
M.mouse = require("config.mouse")
M.visuals = require("config.visuals")
M.animations = require("config.animations")
M.decoration = require("config.decoration")
M.layout = require("config.layout")
M.keybinds = require("config.keybinds")
M.plugin = require("config.plugin")
M.windowrules = require("config.windowrules")
M.layerrules = require("config.layerrules")
M.misc = require("config.misc")
M.debug = require("config.debug")
M.custom = require("local.custom")
M.autostart = require("config.autostart")

function M.setup()
    M.custom.apply()
end

return M