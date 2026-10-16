#!/usr/bin/env python3

import subprocess
import json

def _run(args, timeout=2):
    return subprocess.run(["hyprctl"] + args, capture_output=True, text=True, timeout=timeout)

def hyprctl_json(args, timeout=2):
    r = _run(args + ["-j"], timeout=timeout)
    return json.loads(r.stdout) if r.stdout.strip() else None

def dispatch(lua_expr, timeout=2):
    return _run(["dispatch", lua_expr], timeout=timeout)

def dispatch_async(lua_expr):
    subprocess.Popen(["hyprctl", "dispatch", lua_expr],
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def batch(lua_exprs, timeout=5):
    cmd = " ; ".join(f"dispatch {e}" for e in lua_exprs)
    return subprocess.run(["hyprctl", "--batch", cmd], capture_output=True, timeout=timeout)

def batch_async(lua_exprs):
    if not lua_exprs:
        return
    cmd = " ; ".join(f"dispatch {e}" for e in lua_exprs)
    subprocess.Popen(["hyprctl", "--batch", cmd],
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def toggle_floating_lua(address=None):
    w = f', window = "address:{address}"' if address else ""
    return f'hl.dsp.window.float({{ action = "toggle"{w} }})'

def toggle_floating(address=None):
    return dispatch(toggle_floating_lua(address))

def focus_window_lua(address):
    return f'hl.dsp.focus({{ window = "address:{address}" }})'

def focus_window(address):
    return dispatch(focus_window_lua(address))

def move_focus_lua(direction_lud):
    return f'hl.dsp.focus({{ direction = "{direction_lud}" }})'

def move_focus(direction_lud):
    return dispatch(move_focus_lua(direction_lud))

def move_window_tiled_lua(direction_lud):
    return f'hl.dsp.window.move({{ direction = "{direction_lud}" }})'

def move_window_tiled(direction_lud):
    return dispatch(move_window_tiled_lua(direction_lud))

def exec_cmd_lua(cmd):
    escaped = cmd.replace('\\', '\\\\').replace('"', '\\"')
    return f'hl.dsp.exec_cmd("{escaped}")'

def move_window_exact_lua(x, y, address):
    return (f'hl.dsp.window.move({{ window = "address:{address}", '
            f'x = {int(x)}, y = {int(y)}, relative = false }})')

def move_window_exact(x, y, address, timeout=2):
    return dispatch(move_window_exact_lua(x, y, address), timeout=timeout)

def move_window_exact_async(x, y, address):
    dispatch_async(move_window_exact_lua(x, y, address))

def resize_window_exact_lua(w, h, address):
    return (f'hl.dsp.window.resize({{ window = "address:{address}", '
            f'x = {int(w)}, y = {int(h)}, relative = false }})')

def resize_window_exact(w, h, address, timeout=2):
    return dispatch(resize_window_exact_lua(w, h, address), timeout=timeout)
