#!/bin/bash
# Confirm KWin accepts the uinput keyboard, set the height, and check the back key.
set -u

echo "=== kernel device"
grep -A4 "duo-on-screen keyboard" /proc/bus/input/devices | head -8

echo "=== KWin sees it?"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 bash -c "
for d in \$(dbus-send --session --print-reply --dest=org.kde.KWin /org/kde/KWin/InputDevice \
   org.freedesktop.DBus.Properties.Get string:org.kde.KWin.InputDeviceManager string:devicesSysNames 2>/dev/null |
   grep -o \"event[0-9]*\");
do
  n=\$(dbus-send --session --print-reply --dest=org.kde.KWin /org/kde/KWin/InputDevice/\$d \
      org.freedesktop.DBus.Properties.Get string:org.kde.KWin.InputDevice string:name 2>/dev/null |
      grep -o \"string \\\"[^\\\"]*\\\"\" | head -1)
  case \"\$n\" in *duo-on-screen*) echo \"KWin has: \$d \$n\";; esac
done"' 2>&1 | tail -3

echo "=== raise the keyboard to 660 px"
install -d -o duo -g duo /home/duo/.config/duo
echo 660 > /home/duo/.config/duo/kbd-height
chown duo:duo /home/duo/.config/duo/kbd-height
cat /home/duo/.config/duo/kbd-height

echo "=== restart the keyboard through duo-osk so the toggle state is clean"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 pkill -x wvkbd-mobintl' 2>/dev/null || true
sleep 1
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 /usr/local/bin/duo-osk show' 2>&1 | tail -2
sleep 3
pgrep -af wvkbd-mobintl | head -2
tail -2 /tmp/wvkbd.log 2>/dev/null

echo "=== devices that can emit KEY_F1 (bit 59)"
python3 /tmp/keymap-decode.py 2>/dev/null | grep -i "F1" || echo "  none"
