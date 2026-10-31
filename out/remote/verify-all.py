#!/usr/bin/env python3
"""Verify outputs, inputs and the input stack after the InputPlumber port."""
import json
import os
import shutil
import subprocess


def sock() -> str:
    cands = [f"/run/user/1000/{n}" for n in os.listdir("/run/user/1000") if n.startswith("sway-ipc.")]
    return cands[0] if cands else ""


def as_duo(cmd: str) -> str:
    s = sock()
    env = f"SWAYSOCK={s} XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1"
    return subprocess.run(["su", "-", "duo", "-c", f"{env} {cmd}"],
                          capture_output=True, text=True).stdout


def main() -> None:
    print("=== outputs")
    try:
        for o in json.loads(as_duo("swaymsg -t get_outputs -r")):
            r = o["rect"]
            print(f'{o["name"]:8s} active={str(o["active"]):5s} '
                  f'pos={r["x"]},{r["y"]} size={r["width"]}x{r["height"]} scale={o.get("scale")}')
    except Exception as exc:  # noqa: BLE001
        print("outputs unreadable:", exc)

    print("=== inputs")
    try:
        for i in json.loads(as_duo("swaymsg -t get_inputs -r")):
            print(f'{i.get("type","?"):9s} {i["identifier"]}')
    except Exception as exc:  # noqa: BLE001
        print("inputs unreadable:", exc)

    print("=== services")
    for s in ("inputplumber", "duo-modem", "sshd"):
        st = subprocess.run(["systemctl", "is-active", s], capture_output=True, text=True).stdout.strip()
        print(f"{s:14s} {st}")
    en = subprocess.run(["systemctl", "is-enabled", "duo-inputd"], capture_output=True, text=True).stdout.strip()
    print(f"duo-inputd     {en}")

    print("=== virtual devices")
    out = subprocess.run(["bash", "-c", "for f in /sys/class/input/event*/device/name; do echo \"$f: $(cat $f)\"; done"],
                         capture_output=True, text=True).stdout
    for line in out.strip().splitlines():
        if any(k in line for k in ("InputPlumber", "DualSense", "Retroid", "wvkbd")):
            print("  " + line.split("/")[4] + " " + line.split(": ", 1)[1])


if __name__ == "__main__":
    main()
