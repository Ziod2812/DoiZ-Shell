local animations = {
    enabled = true,

    curves = {
        { name = "easeOutQuint", points = { { 0.23, 1 }, { 0.32, 1 } } },
        { name = "easeInOutCubic", points = { { 0.65, 0 }, { 0.35, 1 } } },
        { name = "easeOutCubic", points = { { 0.33, 1 }, { 0.68, 1 } } },
        { name = "linear", points = { { 0, 0 }, { 1, 1 } } },
        { name = "snappy", points = { { 0.16, 1 }, { 0.3, 1 } } },
        { name = "wsGlide", points = { { 0.22, 1 }, { 0.36, 1 } } },
    },

    animation = {
        { leaf = "windows", speed = 3, bezier = "easeOutQuint", style = "popin" },
        { leaf = "windowsIn", speed = 2.5, bezier = "easeOutQuint", style = "popin 92%" },
        { leaf = "windowsOut", speed = 2, bezier = "easeOutCubic", style = "popin 96%" },
        { leaf = "windowsMove", enabled = false, speed = 1, bezier = "snappy" },
        { leaf = "border", speed = 3, bezier = "easeOutCubic" },
        { leaf = "borderangle", enabled = false, speed = 1, bezier = "linear" },
        { leaf = "fade", speed = 3, bezier = "easeOutCubic" },
        { leaf = "fadeIn", speed = 2.5, bezier = "easeOutCubic" },
        { leaf = "workspaces", speed = 4, bezier = "wsGlide", style = "slidefadevert 30%" },
        { leaf = "workspacesIn", speed = 4, bezier = "wsGlide", style = "slidefadevert 30%" },
        { leaf = "workspacesOut", speed = 3.5, bezier = "wsGlide", style = "slidefadevert 30%" },
        { leaf = "specialWorkspace", speed = 2, bezier = "snappy", style = "slidevert" },
    },
}

hl.config({
    animations = {
        enabled = animations.enabled,
    },
})

for _, curve in ipairs(animations.curves) do
    hl.curve(curve.name, {
        type = "bezier",
        points = curve.points,
    })
end

for _, animation in ipairs(animations.animation) do
    hl.animation({
        leaf = animation.leaf,
        enabled = animation.enabled ~= false,
        speed = animation.speed,
        bezier = animation.bezier,
        style = animation.style,
    })
end

return animations
