#!/bin/bash
# Finish the battery work: drop the unused stopgap plasmoid, confirm autostart,
# and refresh the device-config snapshot taken from the live system.
set -u

echo "=== remove the unused local plasmoid"
rm -rf /usr/share/plasma/plasmoids/org.duo.battery
rm -rf /home/duo/.local/share/plasma/plasmoids/org.duo.battery

echo "=== powerdevil autostart"
ls -l /etc/xdg/autostart/powerdevil.desktop
grep -c powerdevil /home/duo/.config/ksmserverrc 2>/dev/null || true

echo "=== refresh the config snapshot"
rm -rf /tmp/devconf && mkdir -p /tmp/devconf/etc-duo /tmp/devconf/etc-systemd \
    /tmp/devconf/etc-systemd-user /tmp/devconf/etc-inputplumber/profiles \
    /tmp/devconf/etc-polkit /tmp/devconf/etc-udev /tmp/devconf/etc-xdg \
    /tmp/devconf/etc-sudoers
cp /etc/duo/* /tmp/devconf/etc-duo/ 2>/dev/null
cp /etc/systemd/system/duo-*.service /tmp/devconf/etc-systemd/ 2>/dev/null
cp /home/duo/.config/systemd/user/duo-backkey.service /tmp/devconf/etc-systemd-user/ 2>/dev/null
cp /etc/inputplumber/profiles/*.yaml /tmp/devconf/etc-inputplumber/profiles/ 2>/dev/null
rm -f /tmp/devconf/etc-inputplumber/profiles/*.duo-backup
cp /etc/polkit-1/rules.d/*.rules /tmp/devconf/etc-polkit/ 2>/dev/null || true
cp /etc/udev/rules.d/90-touch-output.rules /tmp/devconf/etc-udev/ 2>/dev/null
cp /etc/xdg/kwinrulesrc /tmp/devconf/etc-xdg/ 2>/dev/null
cp /home/duo/.config/kwinrc /tmp/devconf/etc-xdg/kwinrc 2>/dev/null
cp /home/duo/.config/kcminputrc /tmp/devconf/etc-xdg/kcminputrc 2>/dev/null
cp /etc/sudoers.d/duo /tmp/devconf/etc-sudoers/duo 2>/dev/null
cp /usr/local/bin/duo-session /tmp/devconf/duo-session 2>/dev/null
tar czf /tmp/devconf.tgz -C /tmp devconf
ls -l /tmp/devconf.tgz
