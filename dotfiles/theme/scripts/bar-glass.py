#!/usr/bin/env python3

import fcntl
import os
import sys
from pathlib import Path

CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
STATE_FILE = CONFIG_HOME / "mycfg" / "bar-glass"

DEFAULT_PCT = 50
MIN_PCT = 20
MAX_PCT = 100

def _lines():
    try:
        return STATE_FILE.read_text().splitlines()
    except OSError:
        return []

def is_on():
    lines = _lines()
    return bool(lines) and lines[0].strip() == "on"

def get_pct():
    try:
        pct = int(float(_lines()[1].strip()))
    except (IndexError, ValueError):
        pct = DEFAULT_PCT

    return max(MIN_PCT, min(MAX_PCT, pct))

def write_state(on, pct):
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    tmp = STATE_FILE.with_name(STATE_FILE.name + ".tmp")
    tmp.write_text(f"{'on' if on else 'off'}\n{pct}\n")
    os.replace(tmp, STATE_FILE)

def run_cmd(cmd):
    if cmd == "status":
        print("on" if is_on() else "off")
    elif cmd == "level":
        print(get_pct())
    elif cmd == "toggle":
        write_state(not is_on(), get_pct())
    elif cmd in ("on", "off"):
        write_state(cmd == "on", get_pct())
    elif cmd == "alpha" and len(sys.argv) > 2:
        try:
            pct = int(float(sys.argv[2]))
        except ValueError:
            return 2

        write_state(is_on(), max(MIN_PCT, min(MAX_PCT, pct)))
    elif cmd != "apply":
        print("usage: bar-glass.py [status|level|alpha PCT|toggle|on|off]", file=sys.stderr)
        return 2

    return 0

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd in ("status", "level"):
        return run_cmd(cmd)

    lock_path = CONFIG_HOME / "mycfg" / ".bar-glass.lock"
    lock_path.parent.mkdir(parents=True, exist_ok=True)

    with open(lock_path, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        return run_cmd(cmd)

if __name__ == "__main__":
    sys.exit(main())
