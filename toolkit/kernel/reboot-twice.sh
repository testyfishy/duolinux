#!/bin/bash
# Reboot N times and verify the display comes back each time.
set -uo pipefail
SSH="ssh -i $HOME/.ssh/duo_key -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=8 root@192.168.86.33"
N=${1:-2}

check() {
    $SSH '
      echo "  kernel:   $(uname -r)"
      echo "  uptime:   $(uptime -p)"
      echo "  panels:   DSI-1=$(cat /sys/class/drm/card0-DSI-1/status) DP-1=$(cat /sys/class/drm/card0-DP-1/status)"
      echo "  backlight:$(cat /sys/class/backlight/backlight/brightness)/$(cat /sys/class/backlight/backlight/max_brightness)"
      echo "  drm errs: $(dmesg | grep -iE "dsi|panel|bridge|dpu|wl818s" | grep -icE "error|fail|timeout")"
      echo "  panels up:$(dmesg | grep -icE "panel.*(prepare|enable)|dsi.*(enable|ready)")"
      echo "  failed:   $(systemctl list-units --state=failed --no-legend | wc -l)"
      echo "  plasma:   $(su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-active plasma-plasmashell" 2>/dev/null)"
    ' 2>/dev/null
}

for i in $(seq 1 "$N"); do
    echo "=== reboot $i/$N"
    $SSH 'sync; systemctl reboot' 2>/dev/null || true
    sleep 22
    ok=0
    for t in $(seq 1 30); do
        if $SSH 'true' 2>/dev/null; then ok=1; break; fi
        sleep 5
    done
    if [ "$ok" = 0 ]; then echo "  DID NOT COME BACK"; exit 1; fi
    sleep 8
    check
    echo
done
