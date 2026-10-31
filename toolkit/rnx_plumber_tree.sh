#!/bin/bash
set -u
S=/mnt/rnx/SYSTEM
D="/mnt/c/path/to/duolinux/out/rnx-port/plumber-root"
rm -rf "$D"; mkdir -p "$D"

PATHS="
usr/bin/inputplumber
usr/lib/inputplumber
usr/lib/systemd/system/inputplumber.service
usr/lib/systemd/system/inputplumber.service.d
usr/lib/systemd/system/inputplumber-suspend.service
usr/lib/modules-load.d/inputplumber-hrtimer.conf
usr/share/dbus-1/system-services/org.shadowblip.InputPlumber.service
usr/share/dbus-1/system.d/org.shadowblip.InputPlumber.conf
usr/share/inputplumber
usr/lib/udev/rules.d/60-inputplumber-uaccess.rules
usr/lib/udev/rules.d/90-inputplumber-autostart.rules
usr/lib/udev/rules.d/99-inputplumber-device-setup.rules
usr/lib/udev/hwdb.d/59-inputplumber.hwdb
usr/lib/udev/hwdb.d/60-inputplumber-autostart.hwdb
"

echo "=== extracting"
unsquashfs -d "$D" "$S" $PATHS >/dev/null 2>&1 || true

echo "=== result"
find "$D" -type f | sed "s|$D/||" | sort | head -60
echo "=== device profiles mentioning retroid/duo"
grep -ril 'duolite\|retroid' "$D/usr/share/inputplumber" 2>/dev/null | head -10
