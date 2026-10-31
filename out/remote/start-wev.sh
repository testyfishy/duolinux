#!/bin/bash
# Record the actual keysyms Sway delivers, using wev.
set -u
DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::ForceIPv4=true install -y --no-install-recommends wev 2>&1 | tail -2
command -v wev || { echo "wev missing"; exit 1; }

S=$(ls /run/user/1000/sway-ipc.*.sock | head -1)
: > /tmp/wev.log
chmod 666 /tmp/wev.log

# launch it in the session on the main screen
su - duo -c "SWAYSOCK=$S XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 \
  sh -c 'wev > /tmp/wev.log 2>&1'" >/dev/null 2>&1 &
sleep 3
pgrep -a wev | head -3
echo "wev running, log at /tmp/wev.log"
