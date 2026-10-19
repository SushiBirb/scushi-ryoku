#!/bin/bash
# Autostart user apps cleanly after network is available

# 1. Start live wallpaper after desktop shell settles
(
    sleep 2
    if [ -f "$HOME/HyprWpE/config/HyprWpE.sh" ]; then
        bash "$HOME/HyprWpE/config/HyprWpE.sh"
    fi
) &

# 2. Wait up to 6 seconds for network connectivity so apps don't throw connection errors
if [ -x "/usr/lib/systemd/systemd-networkd-wait-online" ]; then
    /usr/lib/systemd/systemd-networkd-wait-online -q --timeout=6 -i enp4s0 2>/dev/null
else
    for i in {1..6}; do
        if ip route get 1.1.1.1 >/dev/null 2>&1; then break; fi
        sleep 1
    done
fi

# 3. Launch autostart apps
command -v zen-browser >/dev/null 2>&1 && zen-browser &
command -v discord >/dev/null 2>&1 && discord &
command -v sone >/dev/null 2>&1 && sone &
command -v steam >/dev/null 2>&1 && steam -silent &

# 4. Start automatic night light scheduler (1-hour sunset ramp)
python3 "$HOME/.config/hypr/scripts/hyprsunset-scheduler.py" --daemon &

