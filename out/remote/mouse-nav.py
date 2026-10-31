#!/usr/bin/env python3
"""Keep d-pad/A/B working for the UI while a mouse profile is loaded."""
import pathlib

NAV = """
  # --- keep UI navigation working in mouse mode ---
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
  - name: A confirm
    source_event: {gamepad: {button: East}}
    target_events:
      - gamepad: {button: East}
      - keyboard: KeyEnter
  - name: B back
    source_event: {gamepad: {button: South}}
    target_events:
      - gamepad: {button: South}
      - keyboard: KeyEsc
"""

for name in ("mouse-right", "mouse-left"):
    p = pathlib.Path(f"/etc/inputplumber/profiles/{name}.yaml")
    t = p.read_text()
    if "keep UI navigation working" in t:
        print(f"{name}: nav already present")
        continue
    p.write_text(t.rstrip() + "\n" + NAV)
    print(f"{name}: nav mappings added")
