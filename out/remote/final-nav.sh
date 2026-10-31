#!/bin/bash
# Final nav mapping: only the two keys a handheld actually needs in menus.
#   A (East)  -> Enter
#   B (South) -> Escape
#   X, Y      -> no keyboard output (gamepad only)
set -u

cp -n /root/default.yaml.orig /usr/share/inputplumber/profiles/default.yaml 2>/dev/null || true

python3 - <<'PY'
import pathlib

p = pathlib.Path("/usr/share/inputplumber/profiles/default.yaml")
text = p.read_text()
marker = "  # --- desktop navigation"
if marker in text:
    text = text.split(marker)[0].rstrip() + "\n"

nav = """
  # --- desktop navigation: d-pad = arrows, A = Enter, B = Escape ---
  - name: DPad Up nav
    source_event: {gamepad: {button: DPadUp}}
    target_events:
      - gamepad: {button: DPadUp}
      - keyboard: KeyUp
  - name: DPad Down nav
    source_event: {gamepad: {button: DPadDown}}
    target_events:
      - gamepad: {button: DPadDown}
      - keyboard: KeyDown
  - name: DPad Left nav
    source_event: {gamepad: {button: DPadLeft}}
    target_events:
      - gamepad: {button: DPadLeft}
      - keyboard: KeyLeft
  - name: DPad Right nav
    source_event: {gamepad: {button: DPadRight}}
    target_events:
      - gamepad: {button: DPadRight}
      - keyboard: KeyRight
  - name: East (physical A) confirm
    source_event: {gamepad: {button: East}}
    target_events:
      - gamepad: {button: East}
      - keyboard: KeyEnter
  - name: South (physical B) back
    source_event: {gamepad: {button: South}}
    target_events:
      - gamepad: {button: South}
      - keyboard: KeyEsc
"""
p.write_text(text.rstrip() + "\n" + nav)
pathlib.Path("/etc/inputplumber/profiles/gamepad.yaml").write_text(p.read_text())
print("nav: d-pad = arrows, A = Enter, B = Esc; X and Y silent")
PY

# Keep DNS alive over the USB route (it broke after a reboot).
if ! grep -q resolvectl /usr/local/bin/duo-usb-route 2>/dev/null; then
  cat >> /usr/local/bin/duo-usb-route <<'EOF'
# DNS for the USB link (usb0 is unmanaged by NetworkManager)
if systemctl is-active systemd-resolved >/dev/null 2>&1; then
  resolvectl dns usb0 1.1.1.1 9.9.9.9 2>/dev/null || true
  resolvectl domain usb0 '~.' 2>/dev/null || true
  resolvectl flush-caches 2>/dev/null || true
fi
EOF
  echo "DNS persistence added to duo-usb-route"
fi

systemctl restart inputplumber
sleep 6
systemctl is-active inputplumber
journalctl -u inputplumber -n 15 --no-pager 2>&1 | grep -iE 'Loading device profile|error|invalid' | tail -2
systemctl restart duo-usb-route 2>/dev/null || true
