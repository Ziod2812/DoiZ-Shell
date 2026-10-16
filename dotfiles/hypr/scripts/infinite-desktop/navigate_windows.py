#!/usr/bin/env python3

import subprocess
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hypr_ipc import hyprctl_json, move_focus, move_window_exact_lua, focus_window, batch_async

PROTECTED_APPS = ['helium', 'helium-browser', 'brave-browser', 'chromium', 'chromium-browser', 'google-chrome',
                  'firefox', 'firefoxdeveloperedition', 'librewolf', 'vivaldi',
                  'opera', 'microsoft-edge']

DIR_SHORT = {"left": "l", "right": "r", "up": "u", "down": "d"}

def movefocus(direction):
    move_focus(DIR_SHORT[direction])

def get_monitor_center():
    monitors = hyprctl_json(["monitors"]) or []
    for m in monitors:
        if m.get("focused"):
            return m["x"] + m["width"] // 2, m["y"] + m["height"] // 2
    return 960, 540

def get_window_center(w):
    return w["at"][0] + w["size"][0] // 2, w["at"][1] + w["size"][1] // 2

def get_window_bounds(w):
    x, y = w["at"][0], w["at"][1]
    ww, wh = w["size"][0], w["size"][1]
    return {"left": x, "right": x+ww, "top": y, "bottom": y+wh,
            "center_x": x+ww//2, "center_y": y+wh//2}

def is_protected(w):
    return any(app in w.get("class", "").lower() for app in PROTECTED_APPS)

def overlap_h(b1, b2):
    return not (b1["right"] <= b2["left"] or b1["left"] >= b2["right"])

def overlap_v(b1, b2):
    return not (b1["bottom"] <= b2["top"] or b1["top"] >= b2["bottom"])

def find_target(floating, current_bounds, center, direction):
    cx, cy = center

    aligned = []
    for w in floating:
        b = get_window_bounds(w)
        wx, wy = b["center_x"], b["center_y"]
        if direction == "left"  and overlap_v(current_bounds, b) and wx < cx:
            aligned.append((w, cx - wx))
        elif direction == "right" and overlap_v(current_bounds, b) and wx > cx:
            aligned.append((w, wx - cx))
        elif direction == "up"   and overlap_h(current_bounds, b) and wy < cy:
            aligned.append((w, cy - wy))
        elif direction == "down" and overlap_h(current_bounds, b) and wy > cy:
            aligned.append((w, wy - cy))

    if aligned:
        return sorted(aligned, key=lambda x: x[1])[0][0]

    same_dir = []
    for w in floating:
        b = get_window_bounds(w)
        wx, wy = b["center_x"], b["center_y"]
        if direction == "left"  and wx < cx: same_dir.append((w, cx - wx))
        elif direction == "right" and wx > cx: same_dir.append((w, wx - cx))
        elif direction == "up"   and wy < cy: same_dir.append((w, cy - wy))
        elif direction == "down" and wy > cy: same_dir.append((w, wy - cy))

    if same_dir:
        return sorted(same_dir, key=lambda x: x[1])[0][0]

    opp = {"left":"right","right":"left","up":"down","down":"up"}[direction]
    wrap = []
    for w in floating:
        b = get_window_bounds(w)
        wx, wy = b["center_x"], b["center_y"]
        if opp == "left"  and wx < cx: wrap.append((w, cx - wx))
        elif opp == "right" and wx > cx: wrap.append((w, wx - cx))
        elif opp == "up"   and wy < cy: wrap.append((w, cy - wy))
        elif opp == "down" and wy > cy: wrap.append((w, wy - cy))

    if wrap:
        return sorted(wrap, key=lambda x: x[1])[0][0]

    return None

def pan_to_window(floating, target_addr, center_x, center_y):
    target = next((w for w in floating if w["address"] == target_addr), None)
    if not target:
        return

    tx = target["at"][0] + target["size"][0] // 2
    ty = target["at"][1] + target["size"][1] // 2
    dx = center_x - tx
    dy = center_y - ty

    exprs = []
    for w in floating:
        nx = w["at"][0] + dx
        ny = w["at"][1] + dy
        exprs.append(move_window_exact_lua(int(nx), int(ny), w["address"]))

    batch_async(exprs)

    if not is_protected(target):
        focus_window(target_addr)

def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("left", "right", "up", "down"):
        print("Usage: navigate_windows.py <left|right|up|down>")
        sys.exit(1)

    direction = sys.argv[1]

    ws = hyprctl_json(["activeworkspace"])
    if not ws:
        sys.exit(1)
    workspace_id = ws["id"]

    clients = hyprctl_json(["clients"]) or []
    ws_clients = [w for w in clients if w.get("workspace", {}).get("id") == workspace_id]
    floating = [w for w in ws_clients if w.get("floating")]

    if not floating:
        movefocus(direction)
        return

    if len(floating) <= 1:
        return

    center_x, center_y = get_monitor_center()
    focused = hyprctl_json(["activewindow"])

    window_near_center = any(
        abs(get_window_center(w)[0] - center_x) < 100 and
        abs(get_window_center(w)[1] - center_y) < 100
        for w in floating
    )

    if not focused or not focused.get("address") or not window_near_center:
        closest = min(
            floating,
            key=lambda w: (
                ((get_window_center(w)[0] - center_x)**2 +
                 (get_window_center(w)[1] - center_y)**2) ** 0.5
                + (1000 if is_protected(w) else 0)
            )
        )
        pan_to_window(floating, closest["address"], center_x, center_y)
        return

    current_bounds = get_window_bounds(focused)
    target = find_target(floating, current_bounds, (center_x, center_y), direction)
    if target:
        pan_to_window(floating, target["address"], center_x, center_y)

if __name__ == "__main__":
    main()
