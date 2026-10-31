#!/bin/bash
# Read-only investigation of the dark second panel.
echo "=== DRM connectors and modes"
for c in /sys/class/drm/card*-*; do
  [ -e "$c" ] || continue
  n=$(basename "$c")
  printf '%-22s status=%-13s enabled=%-9s dpms=%s\n' "$n" \
    "$(cat "$c/status" 2>/dev/null)" "$(cat "$c/enabled" 2>/dev/null)" "$(cat "$c/dpms" 2>/dev/null)"
  printf '   modes: %s\n' "$(tr '\n' ' ' < "$c/modes" 2>/dev/null)"
done

echo "=== deferred probes"
mountpoint -q /sys/kernel/debug || mount -t debugfs none /sys/kernel/debug 2>/dev/null
cat /sys/kernel/debug/devices_deferred 2>/dev/null || echo "(none / not available)"

echo "=== display-related dmesg"
dmesg 2>/dev/null | grep -iE 'dsi|panel|dpu|msm|anx|bridge|drm|hpd|edid' | tail -30

echo "=== panel/bridge nodes in the live DT"
for n in /proc/device-tree/soc@0/display-subsystem@5e00000/dsi@5e94000; do
  [ -d "$n" ] || continue
  echo "--- $n"
  ls "$n" | tr '\n' ' '; echo
  for p in status compatible; do
    [ -e "$n/$p" ] && printf '   %s = %s\n' "$p" "$(tr -d '\0' < "$n/$p")"
  done
done
find /proc/device-tree -maxdepth 3 -iname '*panel*' -o -maxdepth 3 -iname '*bridge*' 2>/dev/null | head -10

echo "=== touchscreens (which bus belongs to the bottom panel)"
for d in /sys/class/input/event4 /sys/class/input/event7; do
  [ -e "$d" ] || continue
  echo "--- $d $(cat "$d/device/name" 2>/dev/null)"
  readlink -f "$d/device" 2>/dev/null
done

echo "=== done"
