"""Device probing, one-shot boot and SD writing."""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

from . import util
from .config import OUT, CACHE


def _tool(name: str) -> str | None:
    env = os.environ.get(name.upper())
    if env and Path(env).exists():
        return env
    found = shutil.which(name)
    if found:
        return found
    candidates = [
        Path(os.environ.get("LOCALAPPDATA", "")) / "Android" / "Sdk" / "platform-tools" / f"{name}.exe",
        Path.home() / "Android" / "Sdk" / "platform-tools" / f"{name}.exe",
        Path(os.environ.get("LOCALAPPDATA", "")) / "Android" / "Sdk" / "platform-tools" / name,
        Path.home() / "Android" / "Sdk" / "platform-tools" / name,
        CACHE / "platform-tools" / "platform-tools" / f"{name}.exe",
        CACHE / "platform-tools" / "platform-tools" / name,
        CACHE / "platform-tools" / f"{name}.exe",
        CACHE / "platform-tools" / name,
    ]
    for c in candidates:
        if c.exists():
            return str(c)
    return None


def ensure_platform_tools() -> None:
    """Download Android platform-tools once if adb/fastboot are missing."""
    if _tool("adb") and _tool("fastboot"):
        return
    if os.name != "nt" and not sys.platform.startswith("linux"):
        return
    import zipfile
    util.banner("Android platform-tools")
    plat = "windows" if os.name == "nt" else "linux"
    url = f"https://dl.google.com/android/repository/platform-tools-latest-{plat}.zip"
    archive = CACHE / "platform-tools.zip"
    util.download(url, archive)
    dest = CACHE / "platform-tools"
    dest.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as z:
        z.extractall(dest)
    for name in ("adb", "fastboot"):
        exe = _tool(name)
        if exe and not os.access(exe, os.X_OK):
            os.chmod(exe, 0o755)
    if not (_tool("adb") and _tool("fastboot")):
        util.die("platform-tools downloaded but adb/fastboot were not found")
    util.ok(f"adb/fastboot in {dest}")


def adb(*args: str, check: bool = False, quiet: bool = True) -> str:
    exe = _tool("adb")
    if not exe:
        util.die("adb not found. Install Android platform-tools or set ADB=path\\to\\adb")
    cmd = [exe]
    serial = load_serial()
    if serial and args and args[0] not in (
        "devices", "pair", "connect", "disconnect", "start-server", "kill-server", "version",
    ):
        cmd += ["-s", serial]
    cmd += list(args)
    p = util.run(cmd, quiet=quiet, check=check)
    return (p.stdout or "").strip()


def adb_raw(*args: str, check: bool = False) -> str:
    exe = _tool("adb")
    if not exe:
        util.die("adb not found. Install Android platform-tools or set ADB=path\\to\\adb")
    p = util.run([exe, *args], quiet=True, check=check)
    return (p.stdout or "").strip()


def load_serial() -> str:
    env = os.environ.get("ANDROID_SERIAL")
    if env:
        return env.strip()
    p = OUT / "device.json"
    if p.exists():
        try:
            return json.loads(p.read_text()).get("serial", "")
        except Exception:  # noqa: BLE001
            return ""
    return ""


def save_serial(serial: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "device.json").write_text(json.dumps({"serial": serial}, indent=2) + "\n")


def fastboot(*args: str, check: bool = False) -> str:
    exe = _tool("fastboot")
    if not exe:
        util.die("fastboot not found. Install Android platform-tools or set FASTBOOT=path")
    p = util.run([exe, *args], quiet=True, check=check)
    return (p.stdout or "").strip()


def probe() -> Path:
    util.banner("device probe")
    ensure_platform_tools()
    dest = OUT / "probe"
    dest.mkdir(parents=True, exist_ok=True)
    report: dict = {"when": time.strftime("%Y-%m-%dT%H:%M:%S"), "adb": {}, "fastboot": {}}

    util.info("adb devices")
    devices = adb("devices", "-l")
    report["adb"]["devices"] = devices
    print(devices or "  (none)")

    if devices and "\tdevice" in devices:
        props = adb("shell", "getprop")
        keep = re.compile(
            r"^\[(ro\.product\.|ro\.boot\.|ro\.build\.|ro\.hardware|ro\.soc|ro\.board|"
            r"ro\.vendor\.product|persist\.panel|ro\.cfg)").pattern
        filtered = [l for l in props.splitlines() if re.match(keep, l)]
        report["adb"]["props"] = filtered
        for cmd, key in (
            ("cat /proc/device-tree/model", "model"),
            ("uname -a", "uname"),
            ("ls -l /dev/block/by-name", "by_name"),
            ("cat /proc/cmdline", "cmdline"),
            ("dumpsys SurfaceFlinger --display-id", "displays"),
            ("ls -l /sys/class/drm", "drm"),
            ("cat /proc/partitions", "partitions"),
        ):
            try:
                report["adb"][key] = adb("shell", cmd)
            except SystemExit:
                report["adb"][key] = ""
        # Input device names matter for the gamepad mapping.
        try:
            report["adb"]["input"] = adb("shell", "cat /proc/bus/input/devices")
        except SystemExit:
            report["adb"]["input"] = ""

    try:
        fb = fastboot("devices")
        report["fastboot"]["devices"] = fb
        if fb:
            report["fastboot"]["getvar"] = fastboot("getvar", "all")
    except SystemExit:
        report["fastboot"]["devices"] = ""

    (dest / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    (dest / "report.txt").write_text(_flatten(report))
    util.ok(f"saved {dest / 'report.json'}")
    _summarise(report)
    return dest


def _flatten(report: dict) -> str:
    lines = []
    for section, vals in report.items():
        if isinstance(vals, dict):
            lines.append(f"## {section}")
            for k, v in vals.items():
                lines.append(f"-- {k}")
                lines.append(str(v))
    return "\n".join(lines) + "\n"


def _summarise(report: dict) -> None:
    props = report.get("adb", {}).get("props", [])
    def get(k: str) -> str:
        for line in props:
            m = re.match(rf"\[{re.escape(k)}\]: \[(.*)\]", line)
            if m:
                return m.group(1)
        return ""
    if props:
        print()
        util.info(f"model      {get('ro.product.model')}")
        util.info(f"device     {get('ro.product.device')}")
        util.info(f"hardware   {get('ro.hardware')}")
        util.info(f"bootloader {get('ro.boot.bootloader')}")
        util.info(f"slot       {get('ro.boot.slot_suffix')}")
        util.info(f"unlocked   {get('ro.boot.verifiedbootstate')}")
    if report.get("fastboot", {}).get("getvar"):
        print()
        util.info("fastboot variables captured; see report.txt")


def reboot_bootloader() -> None:
    util.info("rebooting to bootloader")
    adb("reboot", "bootloader", check=False)
    for _ in range(30):
        time.sleep(1)
        if fastboot("devices", check=False):
            return
    util.die("device did not appear in fastboot")


def boot(image: Path) -> None:
    if not image.exists():
        util.die(f"missing {image}")
    util.banner("one-shot boot (nothing is written)")
    ensure_platform_tools()
    if not fastboot("devices", check=False):
        reboot_bootloader()
    util.run([_tool("fastboot") or "fastboot", "boot", str(image)])
    util.ok("boot image sent; watch the device")


def flash(image: Path, disk: int | str, *, yes: bool = False) -> None:
    if not image.exists():
        util.die(f"missing {image}")
    if sys.platform.startswith("linux"):
        _flash_linux(image, str(disk), yes=yes)
        return
    if os.name == "nt":
        _flash_windows(image, int(disk), yes=yes)
        return
    util.die("flashing is supported on Windows and Linux")


def _flash_windows(image: Path, disk: int, *, yes: bool) -> None:
    ps = (
        f"Get-Disk -Number {disk} | Select-Object Number,FriendlyName,Size,BusType,IsBoot,IsSystem | ConvertTo-Json"
    )
    out = subprocess.run(["powershell", "-NoProfile", "-Command", ps], capture_output=True, text=True)
    if out.returncode != 0:
        util.die("could not inspect disk: " + out.stderr.strip())
    info = json.loads(out.stdout)
    print(json.dumps(info, indent=2))
    if info.get("IsBoot") or info.get("IsSystem"):
        util.die("refusing to write the system/boot disk")
    disk_bytes = int(info.get("Size") or 0)
    if disk_bytes and image.stat().st_size > disk_bytes:
        util.die(f"image is {util.human(image.stat().st_size)}, disk is {util.human(disk_bytes)}")
    if (info.get("BusType") or "").lower() not in ("usb", "sd", "mmc"):
        util.warn(f"disk {disk} reports bus type {info.get('BusType')!r}; expected USB/SD")
    if not yes and not util.confirm(f"ERASE PhysicalDrive{disk} ({info.get('FriendlyName')})?", default=False):
        util.die("cancelled")

    import ctypes
    # Admin check
    if not ctypes.windll.shell32.IsUserAnAdmin():
        util.die("run this in an elevated PowerShell (Administrator)")

    path = rf"\\.\PhysicalDrive{disk}"
    chunk = 8 << 20
    written = 0
    total = image.stat().st_size
    # Remove the old partition table and volume first. Raw writes to a disk with
    # a mounted volume are blocked or truncated by Windows.
    prep = subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         f"Clear-Disk -Number {disk} -RemoveData -Confirm:$false -ErrorAction Stop"],
        capture_output=True, text=True,
    )
    if prep.returncode != 0:
        util.warn("Clear-Disk failed: " + (prep.stderr or prep.stdout).strip())
    # A mounted volume (H:) blocks raw writes. Take the disk offline for the
    # duration, then bring it back so Windows can see the new partitions.
    offline = subprocess.run(
        ["powershell", "-NoProfile", "-Command", f"Set-Disk -Number {disk} -IsOffline $true"],
        capture_output=True, text=True,
    )
    if offline.returncode != 0:
        util.warn("could not take the disk offline; trying the write anyway")
    try:
        with open(path, "r+b", buffering=0) as dev, image.open("rb") as src:
            while True:
                b = src.read(chunk)
                if not b:
                    break
                dev.write(b)
                written += len(b)
                print(f"\r  writing {written * 100 // total:3d}%  {util.human(written)}", end="")
            dev.flush()
            try:
                import os
                os.fsync(dev.fileno())
            except OSError:
                pass
        print()
        util.ok("image written")
    finally:
        subprocess.run(
            ["powershell", "-NoProfile", "-Command", f"Set-Disk -Number {disk} -IsOffline $false"],
            capture_output=True, text=True,
        )


def _flash_linux(image: Path, dev: str, *, yes: bool) -> None:
    if not dev.startswith("/dev/"):
        util.die("pass a block device, e.g. --disk /dev/sdX")
    info = util.capture(["lsblk", "-J", "-o", "NAME,SIZE,TYPE,TRAN,MOUNTPOINT", dev])
    print(info)
    size = util.capture(["lsblk", "-bdn", "-o", "SIZE", dev])
    if size.isdigit() and image.stat().st_size > int(size):
        util.die(f"image is {util.human(image.stat().st_size)}, device is {util.human(int(size))}")
    if not yes and not util.confirm(f"ERASE {dev}?", default=False):
        util.die("cancelled")
    util.run(["sudo", "dd", f"if={image}", f"of={dev}", "bs=8M", "status=progress", "conv=fsync"])
    util.run(["sudo", "sync"])
    util.ok("image written; remove and insert the card")


def list_disks() -> list[dict]:
    if os.name == "nt":
        ps = ("Get-Disk | Select-Object Number,FriendlyName,Size,BusType,IsBoot,IsSystem "
              "| ConvertTo-Json")
        p = subprocess.run(["powershell", "-NoProfile", "-Command", ps], capture_output=True, text=True)
        if p.returncode != 0:
            return []
        try:
            data = json.loads(p.stdout)
        except json.JSONDecodeError:
            return []
        return data if isinstance(data, list) else [data]
    if sys.platform.startswith("linux"):
        p = subprocess.run(["lsblk", "-J", "-d", "-o", "NAME,SIZE,TRAN,MODEL,TYPE"], capture_output=True, text=True)
        try:
            return json.loads(p.stdout).get("blockdevices", [])
        except Exception:  # noqa: BLE001
            return []
    return []


def collect(host: str | None = None) -> None:
    dest = OUT / "collect"
    dest.mkdir(parents=True, exist_ok=True)
    if host:
        util.banner(f"collecting from {host}")
        for name, cmd in {
            "uname": "uname -a",
            "dmesg": "dmesg",
            "drm": "for f in /sys/class/drm/*/status; do echo $f=$(cat $f); done",
            "input": "cat /proc/bus/input/devices",
            "modules": "lsmod",
            "session": "cat ~/.local/state/duo/session.log 2>/dev/null",
        }.items():
            out = util.capture(["ssh", host, cmd], check=False)
            (dest / f"{name}.txt").write_text(out + "\n")
        util.ok(f"logs in {dest}")
        return
    devices = adb("devices")
    if "\tdevice" not in devices:
        util.die("no adb device; pass --host user@duo for a Linux session over ssh")
    for name, cmd in {
        "dmesg": "dmesg",
        "drm": "for f in /sys/class/drm/*/status; do echo $f=$(cat $f); done",
        "input": "cat /proc/bus/input/devices",
    }.items():
        try:
            out = adb("shell", cmd)
        except SystemExit:
            out = ""
        (dest / f"{name}.txt").write_text(out + "\n")
    util.ok(f"logs in {dest}")
