#!/bin/bash
# Deliberate reproduction of the "brightness 0 kills the display" bug, with a
# detached watchdog so the machine cannot be left at a text console.
#
# Watchdog runs independently: after 6 s it restores DP-1 brightness and, if the
# compositor lost the display, re-detects the bridge output.
set -u
RUN() { su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 $*" 2>&1; }

cat > /tmp/watchdog.sh <<'EOF'
#!/bin/bash
sleep 6
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 kscreen-doctor output.DP-1.brightness.70' >/dev/null 2>&1
sleep 2
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 kscreen-doctor output.DP-1.enable' >/dev/null 2>&1
sleep 1
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 kscreen-doctor output.DP-1.position.0,618' >/dev/null 2>&1
echo "$(date +%H:%M:%S) watchdog done" >> /tmp/brightness-test.log
EOF
chmod 755 /tmp/watchdog.sh
setsid /tmp/watchdog.sh >/dev/null 2>&1 < /dev/null &

LOG=/tmp/brightness-test.log
: > "$LOG"
{
  echo "=== before:"
  RUN kscreen-doctor -o | sed 's/\x1b\[[0-9;]*m//g' | grep -E "Output:|enabled|Brightness control"
  echo "kwin=$(pgrep -c kwin_wayland) plasmashell=$(pgrep -c plasmashell)"

  echo "=== setting DP-1 brightness to 0 NOW ($(date +%H:%M:%S))"
  RUN kscreen-doctor output.DP-1.brightness.0

  sleep 10

  echo "=== after 10 s:"
  echo "kwin=$(pgrep -c kwin_wayland) plasmashell=$(pgrep -c plasmashell) vt=$(cat /sys/class/tty/tty0/active)"
  RUN kscreen-doctor -o | sed 's/\x1b\[[0-9;]*m//g' | grep -E "Output:|enabled|Brightness control"
  echo "connectors: DP-1=$(cat /sys/class/drm/card0-DP-1/status) DSI-1=$(cat /sys/class/drm/card0-DSI-1/status)"
  echo "=== kernel messages during the test:"
  dmesg | tail -12
} >> "$LOG" 2>&1

cat "$LOG"
