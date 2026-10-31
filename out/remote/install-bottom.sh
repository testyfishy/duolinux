#!/bin/bash
# Install the bottom-screen support and apply it to the running session.
set -u

install -m 755 /tmp/duo-bottom-detect /usr/local/bin/duo-bottom-detect
install -m 755 /tmp/duo-display /usr/local/bin/duo-display

# Let the desktop user trigger the connector re-detect without a password.
cat > /etc/sudoers.d/duo-bottom <<'EOF'
duo ALL=(root) NOPASSWD: /usr/local/bin/duo-bottom-detect
EOF
chmod 440 /etc/sudoers.d/duo-bottom
visudo -c >/dev/null 2>&1 && echo "sudoers ok"

echo "=== force detect now"
/usr/local/bin/duo-bottom-detect

echo "=== apply display config as duo"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 /usr/local/bin/duo-display' 2>&1 | tail -5

sleep 2
echo "=== outputs"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 swaymsg -t get_outputs -r' 2>/dev/null \
  | python3 -c 'import json,sys
for o in json.load(sys.stdin):
    print(f"{o[\"name\"]:8s} enabled={o[\"active\"]} mode={o.get(\"current_mode\")} pos={o[\"rect\"][\"x\"]},{o[\"rect\"][\"y\"]} size={o[\"rect\"][\"width\"]}x{o[\"rect\"][\"height\"]} scale={o.get(\"scale\")}")'
