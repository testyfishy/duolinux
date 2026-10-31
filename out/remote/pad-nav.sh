#!/bin/bash
# Make the pad able to drive keyboard UIs (fuzzel, nmtui, foot) WITHOUT taking
# anything away from games: every nav button emits BOTH the gamepad event and a
# keyboard key.
set -u

cp -n /usr/share/inputplumber/profiles/default.yaml /root/default.yaml.orig
cp -n /usr/share/inputplumber/profiles/default.yaml /etc/inputplumber/profiles/gamepad.yaml

python3 - <<'PY'
import pathlib

p = pathlib.Path("/usr/share/inputplumber/profiles/default.yaml")
text = p.read_text()

if "DPad Up nav" in text:
    print("nav mappings already present")
else:
    extra = """
  # --- desktop navigation: emit keyboard keys alongside the gamepad events ---
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
  - name: South nav
    source_event: {gamepad: {button: South}}
    target_events:
      - gamepad: {button: South}
      - keyboard: KeyEnter
  - name: East nav
    source_event: {gamepad: {button: East}}
    target_events:
      - gamepad: {button: East}
      - keyboard: KeyEsc
  - name: West nav
    source_event: {gamepad: {button: West}}
    target_events:
      - gamepad: {button: West}
      - keyboard: KeyTab
"""
    p.write_text(text.rstrip() + "\n" + extra)
    print("nav mappings added to default.yaml")

# keep the mouse-mode hand-off profile in sync
q = pathlib.Path("/etc/inputplumber/profiles/gamepad.yaml")
q.write_text(p.read_text())
print("gamepad.yaml refreshed")
PY

echo "=== restarting InputPlumber"
systemctl restart inputplumber
sleep 6
systemctl is-active inputplumber
journalctl -u inputplumber -n 25 --no-pager 2>&1 | grep -iE 'profile|error|warn|target' | tail -8
