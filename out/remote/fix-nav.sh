#!/bin/bash
# Fix the nav mappings using InputPlumber's own naming, verified from the key log:
#   their "South" = physical B   (BTN_SOUTH)
#   their "East"  = physical A   (BTN_EAST)
#   their "North" = physical Y   (BTN_WEST)   <- left
#   their "West"  = physical X   (BTN_NORTH)  <- top; must NOT emit a key
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
  # --- desktop navigation (physical: A=right, B=bottom, Y=left, X=top) ---
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
  - name: North (physical Y) tab
    source_event: {gamepad: {button: North}}
    target_events:
      - gamepad: {button: North}
      - keyboard: KeyTab
"""
p.write_text(text.rstrip() + "\n" + nav)
pathlib.Path("/etc/inputplumber/profiles/gamepad.yaml").write_text(p.read_text())
print("nav mappings: East->Enter, South->Esc, North(Y)->Tab, nothing on X")
PY

systemctl restart inputplumber
sleep 6
systemctl is-active inputplumber
journalctl -u inputplumber -n 20 --no-pager 2>&1 | grep -iE 'Loading device profile|error|invalid' | tail -3

echo "=== restart the key log for the next attempt"
pkill -f duo-keylog 2>/dev/null || true
setsid nohup /usr/local/bin/duo-keylog >/dev/null 2>&1 </dev/null &
sleep 1
echo "keylog restarted"
