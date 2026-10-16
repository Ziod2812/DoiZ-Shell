#!/usr/bin/env python3

import re
import subprocess
import sys
import time

ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")
MAC = re.compile(r"(?:[0-9a-f]{2}:){5}[0-9a-f]{2}", re.I)
NETWORK = re.compile(
    r"^\s*(>)?\s*(.+?)\s{2,}(open|psk|8021x|wep)\s+(\S+)\s*$", re.I
)
SECURITY_LABEL = {"open": "", "psk": "WPA2", "8021x": "802.1X", "wep": "WEP"}

def run(args, timeout=15):
    try:
        r = subprocess.run(
            ["iwctl"] + args,
            capture_output=True,
            text=True,
            timeout=timeout,
            stdin=subprocess.DEVNULL,
        )
    except (OSError, subprocess.TimeoutExpired):
        return "", 1
    return ANSI.sub("", r.stdout + r.stderr), r.returncode

def find_device():
    out, _ = run(["device", "list"])
    fallback = None
    for line in out.splitlines():
        parts = line.split()
        if len(parts) < 2 or not MAC.fullmatch(parts[1]):
            continue
        if "station" in parts:
            return parts[0]
        if fallback is None:
            fallback = parts[0]
    return fallback

def signal_percent(token):
    if set(token) == {"*"}:
        return min(100, len(token) * 25)
    try:
        value = float(token)
    except ValueError:
        return 0
    if abs(value) > 200:
        value /= 100.0
    return max(0, min(100, int(2 * (value + 100))))

def escape_ssid(ssid):
    return ssid.replace("\\", "\\\\").replace(":", "\\:")

def station_info(device):
    out, _ = run(["station", device, "show"])
    state = re.search(r"^\s*State\s+(\S+)", out, re.M)
    network = re.search(r"^\s*Connected network\s+(.+?)\s*$", out, re.M)
    rssi = re.search(r"^\s*RSSI\s+(-?\d+)", out, re.M)
    return (
        state.group(1) if state else "",
        network.group(1) if network else "",
        int(rssi.group(1)) if rssi else None,
    )

def sh(args, timeout=5):
    try:
        r = subprocess.run(
            args, capture_output=True, text=True, timeout=timeout,
            stdin=subprocess.DEVNULL,
        )
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return r.stdout.strip()

def fallback_ssid(device):
    m = re.search(r"^\s*SSID:\s*(.+?)\s*$", sh(["iw", "dev", device, "link"]), re.M)
    if m:
        return m.group(1)
    out = sh(["iwgetid", device, "-r"]) or sh(["iwgetid", "-r"])
    if out:
        return out.splitlines()[0].strip()
    for line in sh(["nmcli", "-t", "-f", "active,ssid", "dev", "wifi"]).splitlines():
        if line.startswith("yes:"):
            return line[4:].replace("\\:", ":")
    return ""

def cmd_list(rescan):
    device = find_device()
    if not device:
        return 0
    if rescan:
        run(["station", device, "scan"])
        time.sleep(1.5)
    state, current, rssi = station_info(device)
    if state != "connected":
        current = ""
    if not current:
        current = fallback_ssid(device)
    out, _ = run(["station", device, "get-networks", "rssi-dbms"])
    if not any(NETWORK.match(line) for line in out.splitlines()):
        out, _ = run(["station", device, "get-networks"])
    found = False
    for line in out.splitlines():
        m = NETWORK.match(line)
        if not m:
            continue
        marker, ssid, security, signal = m.groups()
        ssid = ssid.strip()
        active = bool(marker) or (bool(current) and ssid == current)
        found = found or active
        label = SECURITY_LABEL.get(security.lower(), "")
        print(
            "%s:%d:%s:%s"
            % (
                "yes" if active else "no",
                signal_percent(signal),
                label,
                escape_ssid(ssid),
            )
        )
    if not found and not current:
        try:
            with open("/tmp/doiz-iwd-debug.txt", "w") as f:
                f.write("device=%s\n--- station show\n%s\n--- get-networks\n%s\n"
                        % (device, run(["station", device, "show"])[0], out))
        except OSError:
            pass
    if current and not found:
        strength = max(0, min(100, 2 * (rssi + 100))) if rssi is not None else 50
        print("yes:%d:WPA2:%s" % (strength, escape_ssid(current)))
    return 0

def cmd_connect(ssid, passphrase=None):
    device = find_device()
    if not device or not ssid:
        return 1
    args = []
    if passphrase:
        args += ["--passphrase", passphrase]
    args += ["station", device, "connect", ssid]
    run(args, timeout=40)
    for _ in range(10):
        state, network, _ = station_info(device)
        if state == "connected" and network == ssid:
            return 0
        time.sleep(0.5)
    return 1

def cmd_disconnect():
    device = find_device()
    if not device:
        return 1
    _, rc = run(["station", device, "disconnect"])
    return rc

def cmd_forget(ssid):
    device = find_device()
    if not ssid:
        return 1
    if device:
        run(["station", device, "disconnect"])
    _, rc = run(["known-networks", ssid, "forget"])
    return rc

def powered(device):
    out, _ = run(["device", device, "show"])
    m = re.search(r"Powered\s+(on|off)\b", out)
    return bool(m) and m.group(1) == "on"

def cmd_state():
    device = find_device()
    print("enabled" if device and powered(device) else "disabled")
    return 0

def cmd_toggle():
    device = find_device()
    if not device:
        return 1
    target = "off" if powered(device) else "on"
    _, rc = run(["device", device, "set-property", "Powered", target])
    return rc

def nm_run(args, timeout=45):
    try:
        r = subprocess.run(
            ["nmcli"] + args,
            capture_output=True,
            text=True,
            timeout=timeout,
            stdin=subprocess.DEVNULL,
        )
    except (OSError, subprocess.TimeoutExpired):
        return "", 1
    return r.stdout, r.returncode

def use_nm():
    out = sh(["nmcli", "-t", "-f", "RUNNING", "general"])
    return out.strip() == "running"

def nm_split(line, n):
    parts, cur, i = [], "", 0
    while i < len(line) and len(parts) < n:
        ch = line[i]
        if ch == "\\" and i + 1 < len(line):
            cur += line[i:i + 2]
            i += 2
            continue
        if ch == ":":
            parts.append(cur)
            cur = ""
        else:
            cur += ch
        i += 1
    return parts, line[i:]

def nm_unescape(text):
    return text.replace("\\:", ":").replace("\\\\", "\\")

def nm_wifi_device():
    out, _ = nm_run(["-t", "-f", "DEVICE,TYPE", "device"])
    for line in out.splitlines():
        dev, _, typ = line.partition(":")
        if typ == "wifi":
            return dev
    return ""

def nm_list(rescan):
    args = ["-t", "-f", "IN-USE,SIGNAL,SECURITY,SSID", "device", "wifi", "list",
            "--rescan", "yes" if rescan else "no"]
    out, _ = nm_run(args, timeout=30)
    for line in out.splitlines():
        parts, ssid = nm_split(line, 3)
        if len(parts) < 3 or not ssid:
            continue
        inuse, signal, security = parts
        sec = "" if security in ("", "--") else security.split()[0]
        print("%s:%s:%s:%s" % (
            "yes" if inuse.strip() == "*" else "no",
            signal if signal.isdigit() else "0",
            sec,
            ssid,
        ))
    return 0

def nm_profiles(ssid):
    out, _ = nm_run(["-t", "-f", "NAME,TYPE", "connection", "show"])
    names = []
    for line in out.splitlines():
        parts, rest = nm_split(line, 1)
        if parts and rest == "802-11-wireless" and nm_unescape(parts[0]) == ssid:
            names.append(ssid)
    return names

def nm_connect(ssid, passphrase=None):
    if not ssid:
        return 1
    dev = nm_wifi_device()
    base = ["-w", "40"]
    if passphrase:
        for _ in nm_profiles(ssid):
            nm_run(["connection", "delete", "id", ssid])
        args = base + ["device", "wifi", "connect", ssid, "password", passphrase]
        if dev:
            args += ["ifname", dev]
        _, rc = nm_run(args)
        if rc != 0:
            nm_run(["connection", "delete", "id", ssid])
        return rc
    if nm_profiles(ssid):
        _, rc = nm_run(base + ["connection", "up", "id", ssid])
        if rc == 0:
            return 0
    args = base + ["device", "wifi", "connect", ssid]
    if dev:
        args += ["ifname", dev]
    _, rc = nm_run(args)
    return rc

def nm_disconnect():
    dev = nm_wifi_device()
    if not dev:
        return 1
    _, rc = nm_run(["device", "disconnect", dev])
    return rc

def nm_forget(ssid):
    if not ssid:
        return 1
    nm_disconnect()
    rc = 1
    for _ in nm_profiles(ssid):
        _, rc = nm_run(["connection", "delete", "id", ssid])
    return rc

def nm_state():
    out, _ = nm_run(["radio", "wifi"])
    print("enabled" if out.strip() == "enabled" else "disabled")
    return 0

def nm_toggle():
    out, _ = nm_run(["radio", "wifi"])
    _, rc = nm_run(["radio", "wifi", "off" if out.strip() == "enabled" else "on"])
    return rc

def main(argv):
    if len(argv) < 2:
        return 2
    action = argv[1]
    arg = argv[2] if len(argv) > 2 else ""
    if use_nm():
        if action == "list":
            return nm_list(arg == "rescan")
        if action == "connect":
            return nm_connect(arg)
        if action == "connect-pw":
            return nm_connect(arg, sys.stdin.readline().rstrip("\n"))
        if action == "disconnect":
            return nm_disconnect()
        if action == "forget":
            return nm_forget(arg)
        if action == "state":
            return nm_state()
        if action == "toggle":
            return nm_toggle()
        return 2
    if action == "list":
        return cmd_list(arg == "rescan")
    if action == "connect":
        return cmd_connect(arg)
    if action == "connect-pw":
        passphrase = sys.stdin.readline().rstrip("\n")
        return cmd_connect(arg, passphrase)
    if action == "disconnect":
        return cmd_disconnect()
    if action == "forget":
        return cmd_forget(arg)
    if action == "state":
        return cmd_state()
    if action == "toggle":
        return cmd_toggle()
    return 2

if __name__ == "__main__":
    sys.exit(main(sys.argv))
