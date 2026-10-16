#!/usr/bin/env python3
import json
import os
import socket
import subprocess
import threading
import time

CORE = "infinite_desktop_core.py"

def core_running():
    me = os.getpid()
    for pid in os.listdir("/proc"):
        if not pid.isdigit() or int(pid) == me:
            continue
        try:
            with open(f"/proc/{pid}/cmdline", "rb") as f:
                args = f.read().split(b"\0")
        except OSError:
            continue
        if any(a.decode(errors="ignore").endswith(CORE) for a in args):
            return True
    return False

def clients():
    r = subprocess.run(["hyprctl", "clients", "-j"], capture_output=True, text=True, timeout=2)
    return json.loads(r.stdout) if r.stdout.strip() else []

def float_windows(addresses):
    if not addresses:
        return
    cmd = " ; ".join(
        f'dispatch hl.dsp.window.float({{ action = "toggle", window = "address:{a}" }})'
        for a in addresses
    )
    subprocess.run(["hyprctl", "--batch", cmd], capture_output=True, timeout=5)

def float_all_tiled():
    float_windows([
        c["address"] for c in clients()
        if c.get("mapped", True) and not c.get("floating") and not c.get("fullscreen")
    ])

def parse_open(line):
    if not line.startswith("openwindow>>"):
        return None
    address = line.split(">>", 1)[1].split(",", 1)[0]
    return "0x" + address

def handle_open(address):
    time.sleep(0.08)
    for c in clients():
        if c["address"] == address:
            if not c.get("floating") and not c.get("fullscreen"):
                float_windows([address])
            return

def watch_state():
    was_running = False
    while True:
        running = core_running()
        if running and not was_running:
            try:
                float_all_tiled()
            except Exception:
                pass
        was_running = running
        time.sleep(1)

def main():
    path = os.path.join(
        os.environ["XDG_RUNTIME_DIR"], "hypr",
        os.environ["HYPRLAND_INSTANCE_SIGNATURE"], ".socket2.sock",
    )
    threading.Thread(target=watch_state, daemon=True).start()
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(path)
    buf = b""
    while True:
        data = sock.recv(4096)
        if not data:
            break
        buf += data
        while b"\n" in buf:
            raw, buf = buf.split(b"\n", 1)
            address = parse_open(raw.decode(errors="ignore"))
            if address and core_running():
                try:
                    handle_open(address)
                except Exception:
                    pass

if __name__ == "__main__":
    main()
