#!/bin/bash
# Standardise the Duo Lite pad layout everywhere:
#   B = South, A = East, Y = West, X = North
# Rebuilds the InputPlumber nav mappings from the pristine backup and installs
# the matching hotkey chord table.
set -u

echo "=== 1. restore the profile from backup, then add the correct nav keys"
if [ -f /root/default.yaml.orig ]; then
  cp /root/default.yaml.orig /usr/share/inputplumber/profiles/default.yaml
  echo "restored from /root/default.yaml.orig"
else
  echo "WARNING: no backup found, editing current file"
fi

python3 - <<'PY'
import pathlib

p = pathlib.Path("/usr/share/inputplumber/profiles/default.yaml")
text = p.read_text()
# drop any previously added nav block
marker = "  # --- desktop navigation"
if marker in text:
    text = text.split(marker)[0].rstrip() + "\n"

nav = """
  # --- desktop navigation (layout: B=South, A=East, Y=West, X=North) ---
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
  - name: A (East) confirm
    source_event: {gamepad: {button: East}}
    target_events:
      - gamepad: {button: East}
      - keyboard: KeyEnter
  - name: B (South) back
    source_event: {gamepad: {button: South}}
    target_events:
      - gamepad: {button: South}
      - keyboard: KeyEsc
  - name: Y (West) tab
    source_event: {gamepad: {button: West}}
    target_events:
      - gamepad: {button: West}
      - keyboard: KeyTab
"""
p.write_text(text.rstrip() + "\n" + nav)

q = pathlib.Path("/etc/inputplumber/profiles/gamepad.yaml")
q.write_text(p.read_text())
print("nav mappings written (South=Esc, East=Enter, West=Tab)")
PY

echo "=== 2. install the standardised hotkeys + guide"
install -m 755 /tmp/padhotkeys /usr/local/bin/padhotkeys
install -m 755 /tmp/duo-help /usr/local/bin/duo-help
python3 -m py_compile /usr/local/bin/padhotkeys && echo "padhotkeys compiles"

echo "=== 3. restart everything that reads them"
systemctl restart inputplumber
sleep 6
systemctl restart duo-padhotkeys
sleep 2

echo "=== 4. state"
systemctl is-active inputplumber duo-padhotkeys
journalctl -u inputplumber -n 30 --no-pager 2>&1 | grep -iE 'Loading device profile|error|invalid' | tail -4
echo "=== 5. profile sanity"
grep -c 'keyboard: Key' /usr/share/inputplumber/profiles/default.yaml
grep -n 'East\|South\|West' /usr/local/bin/padhotkeys | head -6
