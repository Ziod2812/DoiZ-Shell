#!/usr/bin/env python3
import json
import os
import sys
import time
import urllib.request
from datetime import datetime

CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "doiz-weather")
LOC = os.path.join(CACHE, "location.json")
DETAIL = os.path.join(CACHE, "detail.json")
TTL = 600

def get(url, timeout=8):
    req = urllib.request.Request(url, headers={"User-Agent": "doiz-datepopup"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8"))

def kind(code, day=True):
    if code == 0:
        return ("󰖙" if day else "󰖔"), "Clear"
    if code in (1, 2):
        return "󰖕", "Partly cloudy"
    if code == 3:
        return "󰖐", "Overcast"
    if code in (45, 48):
        return "󰖑", "Fog"
    if code in (51, 53, 55, 56, 57):
        return "󰖗", "Drizzle"
    if code in (61, 63, 65, 66, 67, 80, 81, 82):
        return "󰖗", "Rain"
    if code in (71, 73, 75, 77, 85, 86):
        return "󰖘", "Snow"
    if code in (95, 96, 99):
        return "󰖓", "Thunderstorm"
    return "󰖐", "Unknown"

LOC_TTL = 3600

def location():
    old = None
    try:
        with open(LOC, encoding="utf-8") as f:
            d = json.load(f)
        if d.get("latitude") is not None and d.get("success") is not False:
            old = d
            if time.time() - os.path.getmtime(LOC) < LOC_TTL:
                return d
    except Exception:
        pass
    try:
        d = get("https://ipwho.is/")
        if d.get("success") is False or d.get("latitude") is None:
            raise ValueError("no location")
    except Exception:
        if old is not None:
            return old
        raise
    os.makedirs(CACHE, exist_ok=True)
    with open(LOC, "w", encoding="utf-8") as f:
        json.dump(d, f)
    return d

def fetch():
    loc = location()
    url = (
        "https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s"
        "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,is_day,wind_speed_10m,pressure_msl"
        "&hourly=temperature_2m,weather_code,precipitation_probability,is_day"
        "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max"
        "&timezone=auto&forecast_days=6&wind_speed_unit=kmh"
    ) % (loc["latitude"], loc["longitude"])
    raw = get(url, 10)
    return {"loc": {"city": loc.get("city") or "Unknown", "country": loc.get("country") or ""}, "raw": raw}

def build(src):
    raw = src["raw"]
    cur, hr, dy = raw["current"], raw["hourly"], raw["daily"]
    icon, cond = kind(int(cur["weather_code"]), bool(cur.get("is_day", 1)))
    now_h = cur["time"][:13]
    start = 0
    for i, t in enumerate(hr["time"]):
        if t[:13] >= now_h:
            start = i
            break
    hourly = []
    for i in range(start + 1, min(start + 7, len(hr["time"]))):
        ic, _ = kind(int(hr["weather_code"][i]), bool(hr["is_day"][i]))
        hourly.append({
            "t": hr["time"][i][11:16],
            "icon": ic,
            "temp": round(hr["temperature_2m"][i]),
            "pop": hr["precipitation_probability"][i] or 0,
        })
    daily = []
    for i in range(1, min(6, len(dy["time"]))):
        ic, _ = kind(int(dy["weather_code"][i]))
        name = datetime.strptime(dy["time"][i], "%Y-%m-%d").strftime("%a")
        daily.append({
            "day": name,
            "icon": ic,
            "min": round(dy["temperature_2m_min"][i]),
            "max": round(dy["temperature_2m_max"][i]),
            "pop": dy["precipitation_probability_max"][i] or 0,
        })
    return {
        "ok": True,
        "city": src["loc"]["city"],
        "country": src["loc"]["country"],
        "icon": icon,
        "cond": cond,
        "temp": round(cur["temperature_2m"]),
        "feels": round(cur["apparent_temperature"]),
        "humidity": round(cur["relative_humidity_2m"]),
        "wind": round(cur["wind_speed_10m"]),
        "pressure": round(cur["pressure_msl"]),
        "min": round(dy["temperature_2m_min"][0]),
        "max": round(dy["temperature_2m_max"][0]),
        "rain": dy["precipitation_probability_max"][0] or 0,
        "uv": round(dy["uv_index_max"][0] or 0),
        "sunrise": dy["sunrise"][0][11:16],
        "sunset": dy["sunset"][0][11:16],
        "hourly": hourly,
        "daily": daily,
    }

def main():
    src = None
    try:
        if time.time() - os.path.getmtime(DETAIL) < TTL:
            with open(DETAIL, encoding="utf-8") as f:
                src = json.load(f)
    except Exception:
        pass
    if src is None:
        try:
            src = fetch()
            os.makedirs(CACHE, exist_ok=True)
            with open(DETAIL, "w", encoding="utf-8") as f:
                json.dump(src, f)
        except Exception:
            try:
                with open(DETAIL, encoding="utf-8") as f:
                    src = json.load(f)
            except Exception:
                print(json.dumps({"ok": False}))
                return
    try:
        print(json.dumps(build(src), ensure_ascii=False))
    except Exception:
        print(json.dumps({"ok": False}))

if __name__ == "__main__":
    main()
