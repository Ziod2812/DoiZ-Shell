#!/usr/bin/env python3

import subprocess
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hypr_ipc import hyprctl_json, move_window_tiled

DIR_SHORT = {"left": "l", "right": "r", "up": "u", "down": "d"}

def get_layout():
    try:
        r = subprocess.run(["hyprctl", "getoption", "general:layout"],
                           capture_output=True, text=True, timeout=2)
        if "master" in r.stdout.lower():
            return "master"
    except Exception:
        pass
    return "dwindle"

def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("left", "right", "up", "down"):
        print("Usage: move_window_tiled.py <left|right|up|down>")
        sys.exit(1)

    direction = sys.argv[1]

    focused = hyprctl_json(["activewindow"])
    if not focused:
        sys.exit(0)

    if focused.get("floating"):
        scripts_dir = os.path.dirname(os.path.abspath(__file__))
        move_script = os.path.join(scripts_dir, "move_window.py")
        subprocess.run(["python3", move_script, direction], timeout=3)
    else:
        move_window_tiled(DIR_SHORT[direction])

if __name__ == "__main__":
    main()
