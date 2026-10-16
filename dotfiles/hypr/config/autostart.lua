hl.on("hyprland.start", function()
    hl.exec_cmd("$HOME/.config/hypr/scripts/doiz-session &")
    hl.exec_cmd("bash -c 'sleep 5; exec python3 $HOME/.config/hypr/scripts/infinite-desktop/auto_float.py' > /dev/null 2>&1 &")
    local f = io.open((os.getenv("HOME") or "") .. "/.config/mycfg/autostart.txt", "r")

    if f then
        for line in f:lines() do
            if line:match("%S") then
                hl.exec_cmd(line)
            end
        end

        f:close()
    end
end)
