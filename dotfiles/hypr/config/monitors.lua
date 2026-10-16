local monitors = {
    {
        name = "eDP-1",
        resolution = "preferred",
        position = "0x0",
        scale = 1,
    },
}

for _, monitor in ipairs(monitors) do
    hl.monitor({
        output = monitor.name,
        mode = monitor.resolution,
        position = monitor.position,
        scale = monitor.scale,
    })
end

return monitors
