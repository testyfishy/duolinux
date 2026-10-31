#!/bin/bash
# Back button (BTN_BACK -> KEY_F1) toggles the on-screen keyboard.
# Use a Plasma global shortcut so KWin consumes the key before the focused
# application sees an F1 keystroke.
set -u
U=/home/duo

install -d -o duo -g duo "$U/.local/share/applications"
cat > "$U/.local/share/applications/duo-osk-toggle.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=On-screen keyboard
Comment=Show or hide the bottom-panel keyboard
Exec=/usr/local/bin/duo-osk toggle
Icon=input-keyboard
NoDisplay=true
StartupNotify=false
EOF
chown duo:duo "$U/.local/share/applications/duo-osk-toggle.desktop"
update-desktop-database "$U/.local/share/applications" 2>/dev/null || true

echo "=== register F1 as the shortcut"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 kwriteconfig6 --file kglobalshortcutsrc \
    --group services --group duo-osk-toggle.desktop --key _launch F1'
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 kwriteconfig6 --file kglobalshortcutsrc \
    --group services --group duo-osk-toggle.desktop --key _k_friendly_name "On-screen keyboard"'
grep -A3 "duo-osk-toggle" "$U/.config/kglobalshortcutsrc"

echo "=== reload kglobalaccel"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user restart plasma-kglobalaccel.service' 2>&1 | tail -2
sleep 3

echo "=== self-test: inject KEY_F1 through our own keyboard device"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 python3 /tmp/inject-f1.py'
sleep 2
echo "=== keyboard running? (should have toggled)"
pgrep -x wvkbd-mobintl >/dev/null && echo "  keyboard process: running" || echo "  keyboard process: NOT running"
ls -l /run/user/1000/duo-osk.on 2>/dev/null && echo "  state: shown" || echo "  state: hidden"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 spectacle -b -n -o /tmp/f1test.png' 2>&1 | tail -1
