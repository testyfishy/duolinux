"""Host detection, WSL delegation and privilege handling."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

from . import util
from .config import REPO

BUILD_COMMANDS = {
    "setup", "fetch", "kernel", "rootfs", "image", "build", "bootimg", "selftest",
}


def is_windows() -> bool:
    return os.name == "nt"


def is_wsl() -> bool:
    if is_windows():
        return False
    try:
        return "microsoft" in Path("/proc/sys/kernel/osrelease").read_text().lower()
    except OSError:
        return bool(os.environ.get("WSL_DISTRO_NAME"))


def is_linux() -> bool:
    return sys.platform.startswith("linux")


def wsl_distros() -> list[str]:
    if not is_windows():
        return []
    try:
        p = subprocess.run(["wsl.exe", "-l", "-q"], capture_output=True)
    except OSError:
        return []
    raw = p.stdout
    # wsl.exe writes UTF-16LE
    try:
        text = raw.decode("utf-16le")
    except UnicodeDecodeError:
        text = raw.decode("utf-8", "ignore")
    names = [line.strip().replace("\x00", "") for line in text.splitlines()]
    return [n for n in names if n]


def pick_distro() -> str:
    env = os.environ.get("DUO_WSL_DISTRO")
    if env:
        return env
    names = wsl_distros()
    if not names:
        util.die("no WSL distribution found. Install one with: wsl --install -d Ubuntu")
    for want in ("26.04", "24.04", "22.04"):
        for n in names:
            if want in n:
                return n
    for n in names:
        if "ubuntu" in n.lower():
            return n
    return names[0]


def wsl_path(path: Path | str) -> str:
    distro = pick_distro()
    p = subprocess.run(
        ["wsl.exe", "-d", distro, "--", "wslpath", "-a", str(path)],
        capture_output=True,
        text=True,
    )
    if p.returncode != 0:
        util.die("could not translate path into WSL: " + p.stderr.strip())
    return p.stdout.strip()


def delegate(argv: list[str]) -> None:
    """Re-run this CLI inside WSL for commands that need a Linux build host."""
    if not is_windows():
        return
    distro = pick_distro()
    script = wsl_path(REPO / "toolkit" / "duo.py")
    env = dict(os.environ)
    env["DUO_IN_WSL"] = "1"
    env["DUO_WSL_DISTRO"] = distro
    cmd = ["wsl.exe", "-d", distro, "--", "env", "DUO_IN_WSL=1", "python3", script, *argv]
    util.info(f"delegating to WSL ({distro})")
    p = subprocess.run(cmd, env=env)
    raise SystemExit(p.returncode)


def euid() -> int:
    try:
        return os.geteuid()
    except AttributeError:
        return 1


def can_sudo() -> bool:
    if euid() == 0:
        return True
    if not util.which("sudo"):
        return False
    return util.run(["sudo", "-n", "true"], quiet=True, check=False).returncode == 0


def sudo_prefix() -> list[str]:
    return [] if euid() == 0 else ["sudo"]


def userns_ok() -> bool:
    if not is_linux():
        return False
    return util.run(["unshare", "-Ur", "true"], quiet=True, check=False).returncode == 0


def mem_gib() -> float:
    if os.name == "nt":
        try:
            import ctypes

            class MEMORYSTATUSEX(ctypes.Structure):
                _fields_ = [
                    ("dwLength", ctypes.c_ulong),
                    ("dwMemoryLoad", ctypes.c_ulong),
                    ("ullTotalPhys", ctypes.c_ulonglong),
                    ("ullAvailPhys", ctypes.c_ulonglong),
                    ("ullTotalPageFile", ctypes.c_ulonglong),
                    ("ullAvailPageFile", ctypes.c_ulonglong),
                    ("ullTotalVirtual", ctypes.c_ulonglong),
                    ("ullAvailVirtual", ctypes.c_ulonglong),
                    ("ullAvailExtendedVirtual", ctypes.c_ulonglong),
                ]

            stat = MEMORYSTATUSEX()
            stat.dwLength = ctypes.sizeof(stat)
            ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(stat))
            return stat.ullTotalPhys / (1 << 30)
        except Exception:  # noqa: BLE001
            return 0.0
    try:
        text = Path("/proc/meminfo").read_text()
        for line in text.splitlines():
            if line.startswith("MemTotal:"):
                return int(line.split()[1]) / 1024 / 1024
    except OSError:
        pass
    return 0.0


def disk_free_gib(path: Path) -> float:
    import shutil
    try:
        return shutil.disk_usage(path).free / (1 << 30)
    except OSError:
        return 0.0
