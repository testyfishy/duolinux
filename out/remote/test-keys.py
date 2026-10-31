#!/usr/bin/env python3
"""Send real key events to fuzzel from a uinput device and see what it does.

Answers, without anyone touching the device: does fuzzel accept KEY_ENTER and
KEY_ESC, or only some keys (as the pad behaviour suggests)?
"""
from __future__ import annotations

import subprocess
import time

import evdev
from evdev import ecodes as e

KEYS = [e.KEY_ENTER, e.KEY_ESC, e.KEY_TAB, e.KEY_UP, e.KEY_DOWN, e.KEY_LEFT, e.KEY_RIGHT]


def start_fuzzel() -> subprocess.Popen:
    inner = ("export SWAYSOCK=$(ls /run/user/1000/sway-ipc.*.sock | head -1); "
             "export XDG_RUNTIME_DIR=/run/user/1000; "
             "export WAYLAND_DISPLAY=wayland-1; "
             "printf 'alpha\\nbeta\\ngamma\\n' | fuzzel --dmenu --lines 3 --prompt 'test: '")
    return subprocess.Popen(
        ["su", "-", "duo", "-c", inner],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)


def tap(ui, code: int) -> None:
    ui.write(e.EV_KEY, code, 1)
    ui.syn()
    time.sleep(0.15)
    ui.write(e.EV_KEY, code, 0)
    ui.syn()
    time.sleep(0.4)


def trial(name: str, keys: list[int]) -> None:
    ui = evdev.UInput({e.EV_KEY: KEYS}, name="duo-keytest")
    time.sleep(1.5)  # let Sway pick up the new keyboard
    proc = start_fuzzel()
    time.sleep(2.0)
    for k in keys:
        tap(ui, k)
    time.sleep(1.0)
    alive = proc.poll() is None
    if alive:
        proc.kill()
        out = ""
    else:
        out = (proc.stdout.read() or "").strip()
    print(f"{name:22s} still-open={alive!s:5s} output={out!r}")
    ui.close()
    time.sleep(0.5)


def main() -> None:
    trial("down+enter", [e.KEY_DOWN, e.KEY_ENTER])
    trial("enter only", [e.KEY_ENTER])
    trial("escape", [e.KEY_ESC])
    trial("tab then enter", [e.KEY_TAB, e.KEY_ENTER])


if __name__ == "__main__":
    main()
