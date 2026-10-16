#!/usr/bin/env bash
set -uo pipefail

hyprctl reload
notify-send -a "DoiZ" "Hyprland" "Config reloaded"
