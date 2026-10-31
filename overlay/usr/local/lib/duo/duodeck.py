#!/usr/bin/env python3
"""duodeck — the dual-screen cockpit for DuoLinux.

Two modes:
  dashboard  top screen: fleet, LLM/GPU activity, local health
  launcher   bottom screen: big touch targets, SSH hosts, tools

It is deliberately plain: Python stdlib + curses, no GUI toolkit, no daemon
framework. If it crashes, the terminal survives and sway restarts it.
"""

from __future__ import annotations

import argparse
import configparser
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from pathlib import Path

for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except Exception:  # noqa: BLE001
        pass

CONF = Path(os.environ.get("DUO_CONF", "/etc/duo/duo.conf"))
STATE = Path("/run/duo")
SSH_OPTS = [
    "-o", "BatchMode=yes",
    "-o", "ConnectTimeout=4",
    "-o", "StrictHostKeyChecking=accept-new",
    "-o", "ServerAliveInterval=15",
]

DEFAULT_LLM = (
    "echo '== GPU'; "
    "(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu "
    "--format=csv,noheader 2>/dev/null || rocm-smi --showuse --showmemuse 2>/dev/null || true); "
    "echo '== OLLAMA'; (ollama ps 2>/dev/null || true); "
    "echo '== TOP'; ps -eo pcpu,pmem,comm --sort=-pcpu | head -6"
)


# ---------------------------------------------------------------- config


def load_conf() -> configparser.ConfigParser:
    c = configparser.ConfigParser(inline_comment_prefixes=("#",))
    c.read_dict({
        "general": {"refresh": "15", "timezone": ""},
        "ssh": {"hosts": ""},
        "llm": {"host": "", "command": DEFAULT_LLM},
        "tailscale": {"ssh": "true"},
    })
    try:
        c.read(CONF)
    except Exception:  # noqa: BLE001
        pass
    return c


def hosts(c: configparser.ConfigParser) -> list[str]:
    raw = c.get("ssh", "hosts", fallback="")
    return [h.strip() for h in re.split(r"[,\n]", raw) if h.strip()]


def host_label(h: str) -> str:
    return h.split("@")[-1].split(".")[0]


def run(cmd: str | list[str], timeout: float = 6.0) -> str:
    try:
        p = subprocess.run(
            cmd, shell=isinstance(cmd, str), capture_output=True, text=True,
            timeout=timeout, env={**os.environ, "LC_ALL": "C"},
        )
        return (p.stdout or "") + (p.stderr or "")
    except Exception:  # noqa: BLE001
        return ""


def spawn(cmd: str) -> None:
    """Open a command in a terminal on the lower screen."""
    if os.environ.get("SWAYSOCK") and shutil.which("swaymsg"):
        subprocess.Popen(["swaymsg", "exec", f"foot --app-id=duo-term {cmd}"])
    else:
        subprocess.Popen(["foot", "--app-id=duo-term", *shlex.split(cmd)])


# ---------------------------------------------------------------- data


@dataclass
class HostStatus:
    host: str
    online: bool = False
    ms: int = 0
    load: str = ""
    note: str = ""


@dataclass
class State:
    fleet: list[HostStatus] = field(default_factory=list)
    llm: list[str] = field(default_factory=list)
    llm_host: str = ""
    local: dict = field(default_factory=dict)
    tailscale: dict = field(default_factory=dict)
    updated: float = 0.0
    error: str = ""


def read_text(p: str) -> str:
    try:
        return Path(p).read_text().strip()
    except OSError:
        return ""


def local_stats() -> dict:
    d: dict = {}
    try:
        mem = {}
        for line in Path("/proc/meminfo").read_text().splitlines():
            k, v = line.split(":", 1)
            mem[k] = int(v.split()[0])
        d["mem_total"] = mem.get("MemTotal", 0) / 1024 / 1024
        d["mem_avail"] = mem.get("MemAvailable", 0) / 1024 / 1024
    except Exception:  # noqa: BLE001
        pass
    try:
        d["load"] = Path("/proc/loadavg").read_text().split()[0]
    except OSError:
        pass
    for bat in Path("/sys/class/power_supply").glob("BAT*"):
        cap = read_text(str(bat / "capacity"))
        if cap:
            d["battery"] = cap
            d["battery_status"] = read_text(str(bat / "status"))
            break
    best = None
    for zone in Path("/sys/class/thermal").glob("thermal_zone*"):
        t = read_text(str(zone / "temp"))
        typ = read_text(str(zone / "type")).lower()
        if t and any(k in typ for k in ("cpu", "soc", "gpu", "xo")):
            val = int(t) / 1000
            if best is None or val > best:
                best = val
    if best:
        d["temp"] = f"{best:.0f}C"
    wifi = run(["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL", "dev", "wifi"], 3)
    for line in wifi.splitlines():
        parts = line.split(":")
        if len(parts) >= 3 and parts[0] == "yes":
            d["wifi"] = parts[1]
            d["signal"] = parts[2]
            break
    d["hostname"] = read_text("/etc/hostname") or "duo"
    return d


def tailscale_state() -> dict:
    raw = run(["tailscale", "status", "--json"], 4)
    if not raw.strip():
        return {"state": "absent"}
    try:
        j = json.loads(raw)
    except json.JSONDecodeError:
        return {"state": "error"}
    peers = j.get("Peer") or {}
    online = sum(1 for p in peers.values() if p.get("Online"))
    return {
        "state": j.get("BackendState", "?"),
        "self": (j.get("Self") or {}).get("HostName", ""),
        "peers": len(peers),
        "online": online,
    }


def check_host(h: str) -> HostStatus:
    st = HostStatus(host=h)
    t0 = time.monotonic()
    out = run(["ssh", *SSH_OPTS, h, "cat /proc/loadavg; hostname"], 6)
    st.ms = int((time.monotonic() - t0) * 1000)
    lines = [l for l in out.splitlines() if l.strip() and not l.startswith("Warning:")]
    if lines and "Permission denied" not in out and "Could not resolve" not in out:
        st.online = True
        first = lines[0].split()
        if len(first) >= 3:
            st.load = f"{float(first[0]):.1f}"
        st.note = lines[1] if len(lines) > 1 else ""
    return st


def llm_text(c: configparser.ConfigParser) -> tuple[str, list[str]]:
    host = c.get("llm", "host", fallback="").strip()
    cmd = c.get("llm", "command", fallback=DEFAULT_LLM).strip()
    if not host:
        return "", ["no [llm] host configured", "set llm.host = server in /etc/duo/duo.conf"]
    out = run(["ssh", *SSH_OPTS, host, cmd], 12)
    lines = [l.rstrip() for l in out.splitlines() if l.strip()]
    if not lines:
        lines = [f"cannot reach {host}"]
    return host, lines[:12]


class Collector(threading.Thread):
    def __init__(self, c: configparser.ConfigParser, state: State):
        super().__init__(daemon=True)
        self.c = c
        self.s = state
        self.stop = threading.Event()

    def run(self) -> None:
        while not self.stop.is_set():
            self.s.local = local_stats()
            self.s.tailscale = tailscale_state()
            hs = hosts(self.c)
            if hs:
                with ThreadPoolExecutor(max_workers=min(4, len(hs))) as ex:
                    self.s.fleet = list(ex.map(check_host, hs))
            else:
                self.s.fleet = []
            self.s.llm_host, self.s.llm = llm_text(self.c)
            self.s.updated = time.time()
            self.stop.wait(int(self.c.get("general", "refresh", fallback="15")))


# ---------------------------------------------------------------- curses


def init_colors() -> None:
    import curses
    curses.start_color()
    try:
        curses.use_default_colors()
        bg = -1
    except Exception:  # noqa: BLE001
        bg = curses.COLOR_BLACK
    pairs = {
        "dim": (curses.COLOR_BRIGHT_BLACK if hasattr(curses, "COLOR_BRIGHT_BLACK") else curses.COLOR_WHITE, bg),
        "fg": (curses.COLOR_WHITE, bg),
        "cyan": (curses.COLOR_CYAN, bg),
        "green": (curses.COLOR_GREEN, bg),
        "yellow": (curses.COLOR_YELLOW, bg),
        "red": (curses.COLOR_RED, bg),
        "mag": (curses.COLOR_MAGENTA, bg),
        "blue": (curses.COLOR_BLUE, bg),
    }
    for i, (name, (fg, b)) in enumerate(pairs.items(), start=1):
        curses.init_pair(i, fg, b)
    return {name: curses.color_pair(i) for i, name in enumerate(pairs, start=1)}


def put(win, y: int, x: int, text: str, attr: int = 0) -> None:
    import curses
    h, w = win.getmaxyx()
    if y < 0 or y >= h or x >= w:
        return
    try:
        win.addnstr(y, x, text, max(0, w - x - 1), attr)
    except curses.error:
        pass


def box(win, y: int, x: int, h: int, w: int, title: str, attr: int) -> None:
    import curses
    if h < 3 or w < 4:
        return
    for i in range(1, w - 1):
        put(win, y, x + i, "─", attr)
        put(win, y + h - 1, x + i, "─", attr)
    for i in range(1, h - 1):
        put(win, y + i, x, "│", attr)
        put(win, y + i, x + w - 1, "│", attr)
    for yy, xx in ((y, x), (y, x + w - 1), (y + h - 1, x), (y + h - 1, x + w - 1)):
        put(win, yy, xx, "┌┐└┘"[[(y, x), (y, x + w - 1), (y + h - 1, x), (y + h - 1, x + w - 1)].index((yy, xx))], attr)
    if title:
        put(win, y, x + 2, f" {title} ", attr)


def header(win, c, st: State) -> None:
    import curses
    h, w = win.getmaxyx()
    put(win, 0, 1, " DUO ", c["cyan"] | curses.A_BOLD)
    clock = time.strftime("%H:%M")
    put(win, 0, 7, clock, c["fg"] | curses.A_BOLD)
    bits = []
    loc = st.local
    if loc.get("battery"):
        bits.append(f"BAT {loc['battery']}%")
    if loc.get("wifi"):
        bits.append(f"WIFI {loc['wifi']}")
    ts = st.tailscale
    if ts:
        bits.append(f"TS {ts.get('state','?')}")
    if loc.get("temp"):
        bits.append(loc["temp"])
    put(win, 0, max(16, w - len("  ".join(bits)) - 2), "  ".join(bits), c["dim"])


def draw_dashboard(win, c, st: State) -> None:
    import curses
    h, w = win.getmaxyx()
    win.erase()
    header(win, c, st)
    top = 1
    fleet_h = max(4, min(8, len(st.fleet) + 2)) if st.fleet else 4
    box(win, top, 0, fleet_h, w, "FLEET", c["cyan"])
    if not st.fleet:
        put(win, top + 1, 2, "no hosts yet — edit /etc/duo/duo.conf", c["dim"])
        put(win, top + 2, 2, "[ssh] hosts = server, desktop", c["dim"])
    for i, f in enumerate(st.fleet[: fleet_h - 2]):
        y = top + 1 + i
        dot = "●" if f.online else "○"
        attr = c["green"] if f.online else c["red"]
        put(win, y, 2, dot, attr)
        put(win, y, 4, host_label(f.host)[:18].ljust(18), c["fg"] | curses.A_BOLD)
        if f.online:
            put(win, y, 23, f"{f.ms:4d}ms", c["dim"])
            put(win, y, 31, f"load {f.load}", c["fg"])
            if f.note:
                put(win, y, 43, f.note[: max(0, w - 45)], c["dim"])
        else:
            put(win, y, 23, "offline", c["dim"])

    y = top + fleet_h
    remain = h - y - 2
    llm_h = max(5, remain // 2)
    box(win, y, 0, llm_h, w, f"LLM / GPU  {st.llm_host or ''}".rstrip(), c["mag"])
    for i, line in enumerate(st.llm[: llm_h - 2]):
        attr = c["fg"]
        if line.startswith("=="):
            attr = c["mag"] | curses.A_BOLD
        elif "cannot" in line or "no [" in line:
            attr = c["yellow"]
        put(win, y + 1 + i, 2, line[: w - 3], attr)

    y2 = y + llm_h
    loc_h = h - y2 - 1
    if loc_h >= 3:
        box(win, y2, 0, loc_h, w, "LOCAL", c["blue"])
        loc = st.local
        bits = [
            f"CPU {loc.get('load','?')}",
            f"MEM {loc.get('mem_avail',0):.1f}/{loc.get('mem_total',0):.1f}G",
            f"TEMP {loc.get('temp','?')}",
            f"BAT {loc.get('battery','?')}%",
        ]
        put(win, y2 + 1, 2, "   ".join(bits), c["fg"])
        ts = st.tailscale
        if ts:
            put(win, y2 + 2, 2, f"tailscale {ts.get('state')}  {ts.get('online',0)}/{ts.get('peers',0)} peers  {ts.get('self','')}", c["dim"])

    footer = "A open   B back   X keyboard   Y refresh   L1/R1 screen   START menu"
    put(win, h - 1, 1, footer[: w - 2], c["dim"])


def draw_launcher(win, c, app: "Launcher") -> None:
    import curses
    h, w = win.getmaxyx()
    win.erase()
    put(win, 0, 1, " DUO ", c["cyan"] | curses.A_BOLD)
    put(win, 0, 7, "launcher", c["dim"])
    put(win, 0, max(10, w - 12), time.strftime("%H:%M"), c["fg"])

    if app.mode == "hosts":
        put(win, 2, 2, "SSH — choose a host", c["cyan"] | curses.A_BOLD)
        if not app.host_list:
            put(win, 4, 2, "no hosts; edit /etc/duo/duo.conf", c["yellow"])
        for i, host in enumerate(app.host_list[: h - 6]):
            attr = c["fg"]
            if i == app.sel:
                attr = curses.A_REVERSE | curses.A_BOLD
            put(win, 4 + i, 2, f"  {host}  ", attr)
        put(win, h - 1, 1, "enter connect   esc back", c["dim"])
        return

    cols = 2 if w >= 64 else 1
    tile_h = 4
    rows = (len(app.items) + cols - 1) // cols
    start_y = 2
    for i, item in enumerate(app.items):
        r, col = divmod(i, cols)
        x = 1 + col * (w // cols)
        y = start_y + r * tile_h
        if y + tile_h > h - 1:
            break
        tw = w // cols - 2
        selected = i == app.sel
        attr = c["cyan"] if selected else c["dim"]
        box(win, y, x, tile_h, tw, "", attr)
        label_attr = (curses.A_REVERSE | curses.A_BOLD) if selected else (c["fg"] | curses.A_BOLD)
        put(win, y + 1, x + 2, item.label, label_attr)
        put(win, y + 2, x + 2, item.hint[: tw - 3], c["dim"])
    put(win, h - 1, 1, "d-pad move   A select   B back   START dashboard", c["dim"])


@dataclass
class Item:
    label: str
    hint: str
    action: str


class Launcher:
    def __init__(self, c: configparser.ConfigParser, st: State):
        self.c = c
        self.st = st
        self.mode = "grid"
        self.sel = 0
        self.confirm: tuple[str, float] | None = None
        self.host_list = hosts(c)
        self.items = [
            Item("Terminal", "shell on this device", "term"),
            Item("SSH", "connect to a host", "ssh"),
            Item("LLM", "GPU + model activity", "llm"),
            Item("Tailscale", "status / login", "tailscale"),
            Item("Wi-Fi", "NetworkManager", "wifi"),
            Item("Files", "nnn", "files"),
            Item("Keys", "SSH keys and access", "keys"),
            Item("Settings", "edit duo.conf", "settings"),
            Item("Keyboard", "toggle on-screen keys", "osk"),
            Item("Dashboard", "focus the top screen", "dash"),
            Item("Reboot", "restart the device", "reboot"),
            Item("Power off", "shut down", "poweroff"),
        ]

    def move(self, delta: int) -> None:
        n = len(self.items)
        self.sel = (self.sel + delta) % n

    def activate(self) -> None:
        if self.mode == "hosts":
            if self.host_list:
                spawn(f"ssh {shlex.quote(self.host_list[self.sel])}")
            self.mode = "grid"
            return
        item = self.items[self.sel]
        a = item.action
        if a == "term":
            spawn("")
        elif a == "ssh":
            self.mode = "hosts"
            self.sel = 0
        elif a == "llm":
            spawn("/usr/local/bin/duo-llm")
        elif a == "tailscale":
            spawn("/usr/local/bin/duo-tailscale status")
        elif a == "wifi":
            spawn("nmtui")
        elif a == "files":
            spawn("nnn")
        elif a == "keys":
            spawn("/usr/local/bin/duo-keys")
        elif a == "settings":
            spawn("nano /etc/duo/duo.conf")
        elif a == "osk":
            run("pkill -x wvkbd-mobintl || (wvkbd-mobintl -L 300 >/dev/null 2>&1 &)", 2)
        elif a == "dash":
            run("swaymsg workspace 1", 2)
        elif a in ("reboot", "poweroff"):
            now = time.monotonic()
            if self.confirm and self.confirm[0] == a and now - self.confirm[1] < 4:
                run(f"systemctl {a}", 5)
                self.confirm = None
            else:
                self.confirm = (a, now)

    def esc(self) -> None:
        if self.mode == "hosts":
            self.mode = "grid"


def dashboard_main(stdscr) -> None:
    c = init_colors()
    import curses
    curses.curs_set(0)
    stdscr.nodelay(False)
    stdscr.timeout(250)
    stdscr.keypad(True)
    st = State()
    conf = load_conf()
    col = Collector(conf, st)
    col.start()
    while True:
        draw_dashboard(stdscr, c, st)
        stdscr.refresh()
        ch = stdscr.getch()
        if ch in (ord("q"), 27):
            return
        if ch in (ord("r"), curses.KEY_F5):
            st.updated = 0
        if ch in (curses.KEY_ENTER, 10, 13):
            if st.fleet:
                spawn(f"ssh {shlex.quote(st.fleet[0].host)}")
        if ch == curses.KEY_F1:
            spawn("/usr/local/bin/duo-launcher-focus")
        if ch == curses.KEY_F11:
            run("pkill -x wvkbd-mobintl || (wvkbd-mobintl -L 300 >/dev/null 2>&1 &)", 2)


def launcher_main(stdscr) -> None:
    c = init_colors()
    import curses
    curses.curs_set(0)
    stdscr.nodelay(False)
    stdscr.timeout(250)
    stdscr.keypad(True)
    st = State()
    conf = load_conf()
    app = Launcher(conf, st)
    while True:
        draw_launcher(stdscr, c, app)
        if app.confirm and time.monotonic() - app.confirm[1] > 4:
            app.confirm = None
        stdscr.refresh()
        ch = stdscr.getch()
        if app.mode == "hosts":
            if ch in (curses.KEY_UP, ord("k")):
                app.sel = (app.sel - 1) % max(1, len(app.host_list))
            elif ch in (curses.KEY_DOWN, ord("j")):
                app.sel = (app.sel + 1) % max(1, len(app.host_list))
            elif ch in (curses.KEY_ENTER, 10, 13, ord(" ")):
                app.activate()
            elif ch in (27, ord("b")):
                app.esc()
            continue
        if ch in (curses.KEY_UP, ord("k")):
            app.move(-1)
        elif ch in (curses.KEY_DOWN, ord("j")):
            app.move(1)
        elif ch in (curses.KEY_LEFT, ord("h")):
            app.move(-2)
        elif ch in (curses.KEY_RIGHT, ord("l")):
            app.move(2)
        elif ch in (curses.KEY_ENTER, 10, 13, ord(" ")):
            app.activate()
        elif ch in (ord("q"), ord("b")):
            if app.mode == "hosts":
                app.esc()
            else:
                run("swaymsg workspace 1", 2)
        elif ch == curses.KEY_F12:
            app.activate()


# ---------------------------------------------------------------- demo


def demo() -> None:
    st = State(
        fleet=[HostStatus("aran@server", True, 12, "3.2", "gpu-01"),
               HostStatus("desktop", False)],
        llm=["== GPU", "78 %, 21400 MiB, 24576 MiB, 71", "== OLLAMA",
             "NAME ID SIZE PROCESSOR", "llama3.1:70b x 42GB 100% GPU",
             "== TOP", "312 aran python3", "4.1 aran ollama"],
        llm_host="server", local={"battery": "87", "wifi": "home", "temp": "41C",
                                   "load": "0.42", "mem_avail": 5.8, "mem_total": 7.6},
        tailscale={"state": "Running", "peers": 4, "online": 3, "self": "duo"},
        updated=time.time(),
    )
    W = 70

    def row(text: str = "") -> None:
        print("│ " + text[:W].ljust(W) + " │")

    def sep(title: str = "") -> None:
        if title:
            print("├ " + title + " " + "─" * max(0, W - len(title) - 1) + "┤")
        else:
            print("├" + "─" * (W + 2) + "┤")

    print("┌" + "─" * (W + 2) + "┐")
    row("DUO  14:32   BAT 87%   WIFI home   TS Running            41C")
    sep("FLEET")
    for f in st.fleet:
        mark = "●" if f.online else "○"
        tail = f"{f.ms:4d}ms  load {f.load}" if f.online else "offline"
        row(f"{mark} {host_label(f.host):<18} {tail}")
    sep("LLM / GPU  server")
    for line in st.llm:
        row(line)
    sep("LOCAL")
    row("CPU 0.42   MEM 5.8/7.6G   TEMP 41C   TAILSCALE 3/4 peers")
    print("└" + "─" * (W + 2) + "┘")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", nargs="?", default="dashboard", choices=["dashboard", "launcher", "demo", "print"])
    ap.add_argument("what", nargs="?")
    args = ap.parse_args()
    if args.mode == "demo":
        demo()
        return
    if args.mode == "print":
        c = load_conf()
        if args.what == "llm":
            h, lines = llm_text(c)
            print(f"# {h}")
            print("\n".join(lines))
        elif args.what == "local":
            print(json.dumps(local_stats(), indent=2))
        elif args.what == "tailscale":
            print(json.dumps(tailscale_state(), indent=2))
        return
    import curses
    fn = dashboard_main if args.mode == "dashboard" else launcher_main
    curses.wrapper(fn)


if __name__ == "__main__":
    main()
