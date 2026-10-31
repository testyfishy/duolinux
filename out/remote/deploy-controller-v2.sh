#!/bin/bash
# Deploy the corrected controller pipeline and the fan fix.
set -u
install -m 755 /tmp/duo-fan /usr/local/bin/duo-fan
install -m 755 /tmp/duo-controller /usr/local/bin/duo-controller
install -m 755 /tmp/duo-controller-apply /usr/local/bin/duo-controller-apply
install -m 755 /tmp/duo-backkey /usr/local/bin/duo-backkey
python3 -m py_compile /usr/local/bin/duo-fan /usr/local/bin/duo-controller \
    /usr/local/bin/duo-controller-apply /usr/local/bin/duo-backkey \
    && echo "all compile"

cat > /etc/duo/controller.json <<'EOF'
{
  "a": "enter",
  "b": "esc",
  "dpad_down": "down",
  "dpad_left": "left",
  "dpad_right": "right",
  "dpad_up": "up",
  "home": "launcher",
  "l1": "click",
  "l2": "scroll_up",
  "l3": "none",
  "r1": "right_click",
  "r2": "scroll_down",
  "r3": "none",
  "select": "none",
  "start": "none",
  "x": "space",
  "y": "menu"
}
EOF
chmod 644 /etc/duo/controller.json

echo "=== apply controller bindings (also restores mouse mode)"
/usr/local/bin/duo-controller-apply
sleep 5

echo "=== mouse mode now:"
systemctl is-active inputplumber
ls /run/user/1000/duo-mouse.on 2>/dev/null && echo "mouse: on" || echo "mouse: off"

echo "=== fan: claim zones from the governor"
systemctl restart duo-fan
sleep 4
journalctl -u duo-fan -n 4 --no-pager | tail -3
for z in /sys/class/thermal/thermal_zone*; do
  t=$(cat $z/type)
  p=$(cat $z/policy 2>/dev/null)
  case "$t" in cpu-1-*) echo "  $t policy=$p" ;; esac
done

echo "=== back/home key daemon"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user restart duo-backkey'
sleep 2
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 journalctl --user -u duo-backkey -n 2 --no-pager' 2>&1 | tail -2

echo "=== controller rows"
grep -c 'name: Duo ' /etc/inputplumber/profiles/gamepad.yaml
grep -c 'name: Duo ' /etc/inputplumber/profiles/mouse-left.yaml
