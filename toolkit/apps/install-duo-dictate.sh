#!/bin/sh
# Install duo-dictate and give the desktop session access to /dev/uinput.
set -u
echo "=== python3-evdev"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3-evdev >/tmp/evdev-apt.log 2>&1
python3 -c "import evdev; print('  evdev', evdev.__version__ if hasattr(evdev,'__version__') else 'ok')" 2>&1 | tail -1

echo "=== uinput udev rule"
cat > /etc/udev/rules.d/60-duo-uinput.rules <<'EOF'
# Allow the active graphical session to create virtual input devices, which is
# how duo-dictate types: KWin has no zwp_virtual_keyboard_v1 and ydotool is not
# packaged, so uinput is the only path.
KERNEL=="uinput", SUBSYSTEM=="misc", TAG+="uaccess", OPTIONS+="static_node=uinput"
EOF
udevadm control --reload-rules 2>/dev/null
udevadm trigger --name-match=uinput 2>/dev/null
sleep 1
echo "  perms now: $(ls -l /dev/uinput)"

echo "=== install binary"
install -m 755 /tmp/duo-dictate /usr/local/bin/duo-dictate
echo "  $(ls -l /usr/local/bin/duo-dictate | awk '{print $1, $5}')"

echo "=== can the desktop user open uinput?"
su - duo -c 'python3 - <<PY
from evdev import UInput, ecodes as e
try:
    ui = UInput({e.EV_KEY: [e.KEY_A]}, name="duo-test", version=1)
    ui.close()
    print("  uinput: OK")
except Exception as ex:
    print("  uinput:", ex)
PY'
