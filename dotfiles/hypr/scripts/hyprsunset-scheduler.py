#!/usr/bin/env python3
"""
hyprsunset-scheduler.py
Automatic location-based night light scheduler for Hyprland using hyprsunset.

Features:
- Queries local coordinates via IP (cached in ~/.local/state/nightlight-location.json)
- Computes exact local sunrise and sunset using NOAA solar equations (offline)
- 1-hour smooth ramp starting at sunset: transitions from 6500K to night temp
- 1-hour smooth ramp starting at sunrise: transitions from night temp back to 6500K
- Reads target night temperature dynamically from ~/.local/state/ryoku-nightlight (default: 4000K)
- Integrated with Ryoku: updates hyprsunset via hyprctl IPC without screen flickering
"""

import sys
import os
import time
import math
import json
import signal
import datetime
import subprocess
import urllib.request

STATE_DIR = os.path.expanduser("~/.local/state")
LOCATION_CACHE = os.path.join(STATE_DIR, "nightlight-location.json")
RYOKU_NIGHTLIGHT_STATE = os.path.join(STATE_DIR, "ryoku-nightlight")

DEFAULT_LAT = 38.269
DEFAULT_LON = -85.4934
DEFAULT_NIGHT_TEMP = 4000
DAY_TEMP = 6500
RAMP_DURATION_SEC = 3600  # 1 hour ramp

def log(msg):
    now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{now_str}] [nightlight-scheduler] {msg}", flush=True)

def get_saved_night_temp():
    try:
        if os.path.isfile(RYOKU_NIGHTLIGHT_STATE):
            with open(RYOKU_NIGHTLIGHT_STATE, "r") as f:
                val = int(f.read().strip())
                if 1000 <= val <= 10000:
                    return val
    except Exception:
        pass
    return DEFAULT_NIGHT_TEMP

def get_location(force_refresh=False):
    os.makedirs(STATE_DIR, exist_ok=True)
    if not force_refresh and os.path.isfile(LOCATION_CACHE):
        try:
            with open(LOCATION_CACHE, "r") as f:
                data = json.load(f)
                if "lat" in data and "lon" in data:
                    return data
        except Exception:
            pass

    # Fetch from ip-api
    try:
        req = urllib.request.Request("http://ip-api.com/json", headers={"User-Agent": "curl/8.0"})
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode())
            if data.get("status") == "success":
                loc = {
                    "lat": float(data["lat"]),
                    "lon": float(data["lon"]),
                    "city": data.get("city", "Unknown"),
                    "region": data.get("regionName", ""),
                    "country": data.get("country", ""),
                    "timezone": data.get("timezone", "")
                }
                with open(LOCATION_CACHE, "w") as f:
                    json.dump(loc, f, indent=2)
                log(f"Detected location: {loc.get('city')}, {loc.get('region')} ({loc['lat']}, {loc['lon']})")
                return loc
    except Exception as e:
        log(f"Could not fetch location online ({e}). Using cached or default.")

    fallback = {
        "lat": DEFAULT_LAT,
        "lon": DEFAULT_LON,
        "city": "Louisville",
        "region": "Kentucky",
        "country": "USA",
        "timezone": "America/Kentucky/Louisville"
    }
    return fallback

def calculate_solar_times_for_date(lat, lon, local_date, tz):
    noon_local = datetime.datetime.combine(local_date, datetime.time(12, 0), tzinfo=tz)
    noon_utc = noon_local.astimezone(datetime.timezone.utc)
    N = noon_utc.timetuple().tm_yday
    lng_hour = lon / 15.0

    times = {}
    for is_sunrise in [True, False]:
        offset = 6.0 if is_sunrise else 18.0
        t = N + ((offset - lng_hour) / 24.0)
        M = (0.9856 * t) - 3.289
        L = (M + (1.916 * math.sin(math.radians(M))) + (0.020 * math.sin(math.radians(2 * M))) + 282.634) % 360
        RA = (math.degrees(math.atan(0.91764 * math.tan(math.radians(L))))) % 360
        Lquad = (math.floor(L / 90.0)) * 90.0
        RAquad = (math.floor(RA / 90.0)) * 90.0
        RA = (RA + (Lquad - RAquad)) / 15.0
        sinDec = 0.39782 * math.sin(math.radians(L))
        cosDec = math.cos(math.asin(sinDec))
        cosH = (math.cos(math.radians(90.833)) - (sinDec * math.sin(math.radians(lat)))) / (cosDec * math.cos(math.radians(lat)))
        if cosH > 1 or cosH < -1:
            times["sunrise" if is_sunrise else "sunset"] = None
            continue
        if is_sunrise:
            H = (360.0 - math.degrees(math.acos(cosH))) / 15.0
        else:
            H = math.degrees(math.acos(cosH)) / 15.0
        T = H + RA - (0.06571 * t) - 6.622
        UT = (T - lng_hour) % 24.0

        dt_utc = datetime.datetime.combine(noon_utc.date(), datetime.time(0, 0), tzinfo=datetime.timezone.utc) + datetime.timedelta(hours=UT)
        dt_local = dt_utc.astimezone(tz)
        if dt_local.date() < local_date:
            dt_utc += datetime.timedelta(days=1)
            dt_local = dt_utc.astimezone(tz)
        elif dt_local.date() > local_date:
            dt_utc -= datetime.timedelta(days=1)
            dt_local = dt_utc.astimezone(tz)
        times["sunrise" if is_sunrise else "sunset"] = dt_local

    return times.get("sunrise"), times.get("sunset")

def is_hyprsunset_running():
    try:
        res = subprocess.run(["pgrep", "-x", "hyprsunset"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return res.returncode == 0
    except Exception:
        return False

def apply_temperature(temp_k):
    """Applies target temperature using hyprsunset."""
    if temp_k is None:
        if is_hyprsunset_running():
            subprocess.run(["pkill", "-x", "hyprsunset"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            log("Daytime: turned off hyprsunset")
        return

    if is_hyprsunset_running():
        res = subprocess.run(["hyprctl", "hyprsunset", "temperature", str(temp_k)], capture_output=True, text=True)
        if res.returncode != 0:
            subprocess.run(["pkill", "-x", "hyprsunset"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.Popen(["setsid", "hyprsunset", "-t", str(temp_k)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else:
        subprocess.Popen(["setsid", "hyprsunset", "-t", str(temp_k)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        log(f"Started hyprsunset at {temp_k}K")

def evaluate_schedule(now_local, lat, lon, night_temp):
    tz = now_local.tzinfo
    today = now_local.date()
    sr_today, ss_today = calculate_solar_times_for_date(lat, lon, today, tz)

    if not sr_today or not ss_today:
        return None, "solar data unavailable", sr_today, ss_today

    duration = datetime.timedelta(seconds=RAMP_DURATION_SEC)

    # 1. Early morning before sunrise (continuation of night)
    if now_local < sr_today:
        return night_temp, "night (pre-dawn)", sr_today, ss_today

    # 2. Morning transition: sunrise to sunrise + 1h (ramping from night_temp up to DAY_TEMP)
    if sr_today <= now_local < sr_today + duration:
        frac = (now_local - sr_today).total_seconds() / RAMP_DURATION_SEC
        temp = int(night_temp + frac * (DAY_TEMP - night_temp))
        pct = int(frac * 100)
        return temp, f"morning ramp ({pct}% complete -> {DAY_TEMP}K)", sr_today, ss_today

    # 3. Daytime: sunrise + 1h to sunset
    if sr_today + duration <= now_local < ss_today:
        return None, "daytime (off)", sr_today, ss_today

    # 4. Evening transition: sunset to sunset + 1h (ramping from DAY_TEMP down to night_temp)
    if ss_today <= now_local < ss_today + duration:
        frac = (now_local - ss_today).total_seconds() / RAMP_DURATION_SEC
        temp = int(DAY_TEMP - frac * (DAY_TEMP - night_temp))
        pct = int(frac * 100)
        return temp, f"evening ramp ({pct}% complete -> {night_temp}K)", sr_today, ss_today

    # 5. Night: sunset + 1h onwards
    return night_temp, "night (full warmth)", sr_today, ss_today

def print_status():
    loc = get_location()
    now_local = datetime.datetime.now().astimezone()
    night_temp = get_saved_night_temp()
    target_temp, phase, sr, ss = evaluate_schedule(now_local, loc["lat"], loc["lon"], night_temp)
    running = is_hyprsunset_running()

    print("=========================================")
    print("      Hyprsunset Night Light Status      ")
    print("=========================================")
    print(f"Location:           {loc.get('city')}, {loc.get('region')} ({loc.get('lat')}, {loc.get('lon')})")
    print(f"Current Local Time: {now_local.strftime('%Y-%m-%d %H:%M:%S %Z')}")
    print(f"Today Sunrise:      {sr.strftime('%H:%M:%S') if sr else 'N/A'}")
    print(f"Today Sunset:       {ss.strftime('%H:%M:%S') if ss else 'N/A'}")
    print(f"Schedule Phase:     {phase}")
    print(f"Target Temperature: {str(target_temp) + 'K' if target_temp else 'Daylight (6500K / Inactive)'}")
    print(f"Configured Night K: {night_temp}K (from ryoku settings)")
    print(f"Hyprsunset Process: {'Running' if running else 'Inactive'}")
    print("=========================================")

def run_daemon():
    log("Starting hyprsunset auto-scheduler daemon...")
    loc = get_location()
    last_applied_temp = None

    def handle_signal(sig, frame):
        log("Stopping daemon...")
        sys.exit(0)

    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    while True:
        try:
            now_local = datetime.datetime.now().astimezone()
            night_temp = get_saved_night_temp()
            target_temp, phase, _, _ = evaluate_schedule(now_local, loc["lat"], loc["lon"], night_temp)

            if target_temp != last_applied_temp:
                apply_temperature(target_temp)
                last_applied_temp = target_temp
                if target_temp is not None:
                    log(f"Phase: {phase} | Applied {target_temp}K")

        except Exception as e:
            log(f"Error in scheduler loop: {e}")

        time.sleep(30)

if __name__ == "__main__":
    if "--status" in sys.argv:
        print_status()
    elif "--update-location" in sys.argv:
        loc = get_location(force_refresh=True)
        print(f"Updated location: {loc}")
    elif "--once" in sys.argv:
        loc = get_location()
        now_local = datetime.datetime.now().astimezone()
        night_temp = get_saved_night_temp()
        target_temp, phase, _, _ = evaluate_schedule(now_local, loc["lat"], loc["lon"], night_temp)
        log(f"Once: Phase is {phase}. Applying target {target_temp}K")
        apply_temperature(target_temp)
    else:
        run_daemon()
