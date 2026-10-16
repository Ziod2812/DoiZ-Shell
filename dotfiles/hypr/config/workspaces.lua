local workspaces = {
    {
        id = 1,
        name = "一",
        monitor = "",
    },
    {
        id = 2,
        name = "二",
        monitor = "",
    },
    {
        id = 3,
        name = "三",
        monitor = "",
    },
    {
        id = 4,
        name = "四",
        monitor = "",
    },
    {
        id = 5,
        name = "五",
        monitor = "",
    },
    {
        id = 6,
        name = "六",
        monitor = "",
    },
    {
        id = 7,
        name = "七",
        monitor = "",
    },
    {
        id = 8,
        name = "八",
        monitor = "",
    },
    {
        id = 9,
        name = "九",
        monitor = "",
    },
    {
        id = 10,
        name = "十",
        monitor = "",
    },
}

for _, workspace in ipairs(workspaces) do
    local monitor = workspace.monitor

    if monitor == "" then
        hl.workspace_rule({
            workspace = tostring(workspace.id),
            default = true,
            persistent = false,
        })
    else
        hl.workspace_rule({
            workspace = tostring(workspace.id),
            monitor = monitor,
            persistent = false,
        })
    end
end

return workspaces