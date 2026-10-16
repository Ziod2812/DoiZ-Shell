if status is-interactive

    set -g fish_greeting

    set -g fish_color_normal CDD6F4
    set -g fish_color_command 89B4FA
    set -g fish_color_param CDD6F4
    set -g fish_color_keyword CBA6F7
    set -g fish_color_quote A6E3A1
    set -g fish_color_redirection 7AA2F7
    set -g fish_color_end CBA6F7
    set -g fish_color_error F38BA8
    set -g fish_color_comment 444B6A
    set -g fish_color_selection --background=40305F
    set -g fish_color_search_match --background=40305F
    set -g fish_color_operator 7AA2F7
    set -g fish_color_escape F9E2AF
    set -g fish_color_autosuggestion 444B6A

    function fish_prompt
        set -l last_status $status
        set -l cwd (prompt_pwd)

        set -l git_branch ""
        set -l git_status ""

        if command git rev-parse --is-inside-work-tree >/dev/null 2>&1
            set git_branch (git branch --show-current 2>/dev/null)

            if test -n "$git_branch"
                set git_status "  $git_branch"
            end

            if not git diff --quiet 2>/dev/null
                set git_status "$git_status *"
            end

            if not git diff --cached --quiet 2>/dev/null
                set git_status "$git_status +"
            end
        end

        if test $last_status -eq 0
            set_color CBA6F7
            echo -n "╭─ "
        else
            set_color F38BA8
            echo -n "╭─ "
        end

        set_color 89B4FA
        echo -n "$cwd"

        if test -n "$git_status"
            set_color A6E3A1
            echo -n "$git_status"
        end

        echo

        if test $last_status -eq 0
            set_color CBA6F7
            echo -n "╰─❯ "
        else
            set_color F38BA8
            echo -n "╰─❯ "
        end

        set_color normal
    end


    function cava --description 'cava uses config_terminal'
        set -l cfg_home $XDG_CONFIG_HOME
        test -n "$cfg_home"; or set cfg_home $HOME/.config

        if test -f $cfg_home/cava/config_terminal
            command cava -p $cfg_home/cava/config_terminal $argv
        else
            command cava $argv
        end
    end

    function lavat --description 'lavat uses the palette cyan (wallpaper accent)'
        if contains -- -c $argv; or contains -- -p $argv
            command lavat $argv
        else
            command lavat -c cyan -R 1 $argv
        end
    end

end

