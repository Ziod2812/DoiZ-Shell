local namespaces = {
    "^doiz[-_]",
}

for _, namespace in ipairs(namespaces) do
    hl.layer_rule({
        match = { namespace = namespace },
        ignore_alpha = 0,
    })
end

for _, namespace in ipairs({
    "^doiz-launcher$",
    "^doiz-wallpaper-picker$",
    "^doiz-dock$",
}) do
    for _, rule in ipairs({
        { no_anim = true },
        { animation = "none" },
    }) do
        rule.match = { namespace = namespace }
        pcall(hl.layer_rule, rule)
    end
end
