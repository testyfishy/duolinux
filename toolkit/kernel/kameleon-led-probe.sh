#!/bin/sh
# What exactly is Kameleon picking up as a keyboard, and can it be excluded?
set -u
echo "=== LED class devices"
for l in /sys/class/leds/*; do
    [ -e "$l" ] || continue
    echo "  $(basename "$l"):"
    echo "     name=$(cat "$l/name" 2>/dev/null) max=$(cat "$l/max_brightness" 2>/dev/null)"
    echo "     udev: $(udevadm info -q property -p "$l" 2>/dev/null | grep -E 'ID_INPUT|ID_PATH|ID_VENDOR' | tr '\n' ' ')"
done

echo
echo "=== input devices claiming to be keyboards"
while IFS= read -r d; do
    n=$(cat "$d/name" 2>/dev/null)
    [ -n "$n" ] || continue
    caps=$(cat "$d/capabilities/key" 2>/dev/null)
    [ -n "$caps" ] && echo "  $n: $(cat "$d/id/vendor" 2>/dev/null):$(cat "$d/id/product" 2>/dev/null)"
done < <(find /sys/class/input -maxdepth 1 -name 'event*' -o -maxdepth 1 -name 'input*' 2>/dev/null)

echo
echo "=== kameleon state"
dpkg -l | awk '/kameleon/{print "  "$2"="$3}'
ls /home/duo/.config/kameleonrc 2>/dev/null && sed -n '1,20p' /home/duo/.config/kameleonrc 2>/dev/null

echo
echo "=== rgb class devices (device-visible LEDs)"
ls /sys/class/leds/ | grep -i rgb || echo "  none"
echo "=== is there an rgb:status anywhere?"
find /sys -maxdepth 4 -name '*rgb*status*' 2>/dev/null | head -5
