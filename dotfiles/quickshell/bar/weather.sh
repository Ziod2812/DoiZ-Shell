#!/usr/bin/env bash

set -u

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/doiz-weather"
LOCATION_CACHE="$CACHE_DIR/location.json"
WEATHER_CACHE="$CACHE_DIR/weather.json"

mkdir -p "$CACHE_DIR"

if ! command -v curl >/dev/null 2>&1; then
    printf '{"text":"󰖐 --","tooltip":"curl is not installed","class":"unavailable"}\n'
    exit 0
fi

location_valid=false

if [ -s "$LOCATION_CACHE" ]; then
    if python3 - "$LOCATION_CACHE" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as f:
        data = json.load(f)

    if data.get("latitude") is None or data.get("longitude") is None:
        raise ValueError

    if data.get("success") is False:
        raise ValueError
except Exception:
    sys.exit(1)

sys.exit(0)
PY
    then
        location_valid=true
    fi
fi

location_stale=false

if [ "$location_valid" = true ] && [ -n "$(find "$LOCATION_CACHE" -mmin +60 2>/dev/null)" ]; then
    location_stale=true
fi

if [ "$location_valid" = false ] || [ "$location_stale" = true ]; then
    tmp="${LOCATION_CACHE}.tmp"

    if curl -fsSL \
        --retry 2 \
        --retry-delay 1 \
        --max-time 8 \
        "https://ipwho.is/" \
        -o "$tmp"
    then
        if python3 - "$tmp" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as f:
        data = json.load(f)

    if data.get("success") is False:
        raise ValueError

    if data.get("latitude") is None or data.get("longitude") is None:
        raise ValueError
except Exception:
    sys.exit(1)

sys.exit(0)
PY
        then
            mv "$tmp" "$LOCATION_CACHE"
            location_valid=true
        else
            rm -f "$tmp"
        fi
    else
        rm -f "$tmp"
    fi
fi

if [ "$location_valid" = true ]; then
    read -r LAT LON CITY COUNTRY < <(
        python3 - "$LOCATION_CACHE" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)

city = data.get("city") or "Unknown"
country = data.get("country") or ""

print(
    data.get("latitude", ""),
    data.get("longitude", ""),
    city,
    country
)
PY
    )

    if [ -n "${LAT:-}" ] && [ -n "${LON:-}" ]; then
        WEATHER_URL="https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&current=temperature_2m,weather_code,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=3"

        tmp="${WEATHER_CACHE}.tmp"

        if curl -fsSL \
            --retry 2 \
            --retry-delay 1 \
            --max-time 10 \
            "$WEATHER_URL" \
            -o "$tmp"
        then
            if python3 - "$tmp" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as f:
        data = json.load(f)

    current = data.get("current", {})
    daily = data.get("daily", {})

    if "temperature_2m" not in current:
        raise ValueError

    if "weather_code" not in current:
        raise ValueError

    if not daily.get("temperature_2m_max"):
        raise ValueError

    if not daily.get("temperature_2m_min"):
        raise ValueError
except Exception:
    sys.exit(1)

sys.exit(0)
PY
            then
                mv "$tmp" "$WEATHER_CACHE"
            else
                rm -f "$tmp"
            fi
        else
            rm -f "$tmp"
        fi
    fi
fi

if [ ! -s "$WEATHER_CACHE" ]; then
    printf '{"text":"󰖐 --","tooltip":"Weather unavailable","class":"unavailable"}\n'
    exit 0
fi

python3 - "$WEATHER_CACHE" "$LOCATION_CACHE" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as f:
        weather = json.load(f)

    with open(sys.argv[2], encoding="utf-8") as f:
        location = json.load(f)

    current = weather["current"]
    daily = weather["daily"]

    temp = round(float(current["temperature_2m"]))
    code = int(current["weather_code"])
    is_day = int(current.get("is_day", 1))

    city = location.get("city") or "Unknown"
    country = location.get("country") or ""

    minimum = round(float(daily["temperature_2m_min"][0]))
    maximum = round(float(daily["temperature_2m_max"][0]))

    if code == 0:
        icon = "󰖙" if is_day else "󰖔"
        condition = "Clear"
    elif code in (1, 2):
        icon = "󰖕"
        condition = "Partly cloudy"
    elif code == 3:
        icon = "󰖐"
        condition = "Overcast"
    elif code in (45, 48):
        icon = "󰖑"
        condition = "Fog"
    elif code in (51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82):
        icon = "󰖗"
        condition = "Rain"
    elif code in (71, 73, 75, 77, 85, 86):
        icon = "󰖘"
        condition = "Snow"
    elif code in (95, 96, 99):
        icon = "󰖓"
        condition = "Thunderstorm"
    else:
        icon = "󰖐"
        condition = "Unknown"

    location_text = city

    if country:
        location_text += f", {country}"

    tooltip = (
        f"{location_text}\n"
        f"{condition}\n"
        f"Today: {minimum}° – {maximum}°"
    )

    print(
        json.dumps(
            {
                "text": f"{icon} {temp}°",
                "tooltip": tooltip,
                "class": "weather"
            },
            ensure_ascii=False
        )
    )

except Exception:
    print(
        json.dumps(
            {
                "text": "󰖐 --",
                "tooltip": "Weather unavailable",
                "class": "unavailable"
            },
            ensure_ascii=False
        )
    )
PY
