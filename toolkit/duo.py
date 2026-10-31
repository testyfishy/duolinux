#!/usr/bin/env python3
"""DuoLinux command line."""

from __future__ import annotations

import argparse
import os
import platform
import shutil
import sys
import time
from pathlib import Path

for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except Exception:  # noqa: BLE001
        pass

# Make `python3 toolkit/duo.py` work without installation.
sys.path.insert(0, str(Path(__file__).resolve().parent))

from duolib import config, host, util  # noqa: E402
from duolib.config import CFG, OUT, CACHE  # noqa: E402

BUILD = {"setup", "fetch", "kernel", "rootfs", "image", "build", "bootimg", "selftest"}

BANNER = r"""
  ____              _     _     _
 |  _ \ _   _  ___ | |   (_)___| |_
 | | | | | | |/ _ \| |   | / __| __|
 | |_| | |_| | (_) | |___| \__ \ |_
 |____/ \__,_|\___/|_____|_|___/\__|
"""


def main() -> None:
    argv = sys.argv[1:]
    if not argv:
        print(BANNER)
        print(f"  DuoLinux {config.VERSION} ({config.CODENAME})")
        print("  dual-screen Debian for the Retroid Pocket Duo Lite\n")
        print("  duo doctor        check this machine")
        print("  duo setup         install build dependencies")
        print("  duo build         fetch + kernel + rootfs + image")
        print("  duo probe         report from a connected Duo")
        print("  duo wireless      pair adb over Wi-Fi")
        print("  duo boot          one-shot boot (writes nothing)")
        print("  duo install       guided local install")
        print("  duo --help        all commands\n")
        return

    if host.is_windows() and argv[0] in BUILD and not os.environ.get("DUO_IN_WSL"):
        host.delegate(argv)
        return

    ap = argparse.ArgumentParser(prog="duo", description="DuoLinux build and device tool")
    ap.add_argument("--version", action="version", version=f"DuoLinux {config.VERSION}")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("doctor", help="check host, tools and artifacts")
    p = sub.add_parser("setup", help="install build dependencies")
    p.add_argument("--rootless", action="store_true", help="use proot, no sudo")
    p.add_argument("--native", action="store_true", help="use apt + sudo (faster)")

    p = sub.add_parser("fetch", help="fetch kernel, firmware and audio config")
    p.add_argument("--force", action="store_true")

    p = sub.add_parser("kernel", help="configure and build the kernel")
    p.add_argument("--jobs", type=int, default=None)
    p.add_argument("--reconfigure", action="store_true")
    p.add_argument("--clean", action="store_true")

    p = sub.add_parser("rootfs", help="build the Debian rootfs")
    p.add_argument("--force", action="store_true")

    p = sub.add_parser("image", help="assemble the SD image")
    p.add_argument("--size", type=int, default=None, help="total image size in MB")
    p.add_argument("--rootfs", type=Path, default=None)

    p = sub.add_parser("build", help="fetch + kernel + rootfs + image")
    p.add_argument("--size", type=int, default=None)
    p.add_argument("--jobs", type=int, default=None)
    p.add_argument("--skip-rootfs", action="store_true")
    p.add_argument("--skip-kernel", action="store_true")

    p = sub.add_parser("bootimg", help="rebuild boot.img and boot files only")

    p = sub.add_parser("adb", help="run an adb command (pair/connect/devices/...)")
    p.add_argument("args", nargs=argparse.REMAINDER)

    p = sub.add_parser("wireless", help="pair and connect adb over Wi-Fi")

    p = sub.add_parser("probe", help="collect a report from the connected device")

    p = sub.add_parser("boot", help="one-shot fastboot boot (non-destructive)")
    p.add_argument("--image", type=Path, default=None)

    p = sub.add_parser("flash", help="write the image to a microSD card")
    p.add_argument("--disk", required=True, help="Windows disk number or /dev/sdX")
    p.add_argument("--yes", action="store_true")

    p = sub.add_parser("install", help="guided install to the device")
    p.add_argument("--disk", default=None)
    p.add_argument("--yes", action="store_true")
    p.add_argument("--via-adb", action="store_true")
    p.add_argument("--with-abl", action="store_true",
                   help="also flash the SM6115 ABL (backs up the stock one first)")

    p = sub.add_parser("collect", help="pull logs from a booted Linux session")
    p.add_argument("--host", default=None)

    p = sub.add_parser("demo", help="print a cockpit preview")

    p = sub.add_parser("selftest", help="run the offline test suite")

    args = ap.parse_args(argv)
    CFG.ensure_dirs()

    fn = globals().get("cmd_" + args.cmd)
    if not fn:
        util.die("unknown command")
    fn(args)


# ---------------------------------------------------------------- housekeeping


def cmd_doctor(args) -> None:
    util.banner("host")
    util.info(f"os        {platform.platform()}")
    util.info(f"python    {sys.version.split()[0]}")
    util.info(f"windows   {host.is_windows()}   wsl {host.is_wsl()}")
    util.info(f"cpu       {os.cpu_count()} threads   mem {host.mem_gib():.1f} GiB")
    util.info(f"cache     {CACHE}  ({host.disk_free_gib(CACHE):.1f} GiB free)")
    util.info(f"out       {OUT}")

    util.banner("tools on this host")
    for t in ("git", "make", "gcc", "aarch64-linux-gnu-gcc", "mmdebstrap",
              "mke2fs", "mkfs.vfat", "mcopy", "adb", "fastboot"):
        p = util.which(t)
        print(f"  {'✓' if p else '·'} {t:<24} {p or ''}")

    if host.is_linux():
        from duolib.builder import BuildEnv
        env = BuildEnv()
        util.info(f"build env {env.describe()}")
        if not env.ready:
            util.warn("run: duo setup")
    if host.is_windows():
        util.info(f"wsl distro {host.pick_distro() if host.wsl_distros() else '(none)'}")

    util.banner("artifacts")
    for label, p in (
        ("kernel", config.KERNEL_ARTIFACTS / "Image"),
        ("dtb", config.KERNEL_ARTIFACTS / CFG.kernel.dtb),
        ("modules", config.KERNEL_ARTIFACTS / "modules"),
        ("rootfs", config.ROOTFS_DIR / "etc/os-release"),
        ("image", OUT / config.IMAGE_NAME),
        ("boot.img", OUT / config.BOOTIMG_NAME),
    ):
        print(f"  {'✓' if p.exists() else '·'} {label:<10} {p}")
    print()
    util.info("next: duo setup --native   then   duo build")


def cmd_setup(args) -> None:
    if not host.is_linux():
        util.die("setup must run inside Linux/WSL")
    from duolib.builder import BuildEnv
    env = BuildEnv()
    if args.rootless:
        env._setup_proot()
    elif args.native:
        env._setup_native()
    else:
        if host.euid() == 0 or host.can_sudo():
            env.setup()
        else:
            util.warn("no passwordless sudo; using the rootless proot environment")
            util.info("for a faster build later: duo setup --native")
            env._setup_proot()
    util.ok("setup complete")


def cmd_fetch(args) -> None:
    from duolib import fetch
    fetch.all(force=args.force)


def cmd_kernel(args) -> None:
    from duolib import fetch, kernel
    if CFG.kernel.mode == "rocknix":
        fetch.rocknix()
        kernel.build(jobs=args.jobs)
        return
    if not (CACHE / "linux" / "Makefile").exists():
        fetch.kernel()
    if args.reconfigure or not (CACHE / "linux" / ".config").exists():
        kernel.configure(clean=args.clean)
    kernel.build(jobs=args.jobs, clean=args.clean)


def cmd_rootfs(args) -> None:
    from duolib import fetch, rootfs
    if CFG.firmware.mode == "rocknix":
        base = fetch.rocknix()
        fetch.rocknix_system(base)
    elif not (CACHE / "firmware" / ".complete").exists():
        fetch.firmware()
    rootfs.build(force=args.force)


def cmd_image(args) -> None:
    from duolib import build
    build.build(total_mb=args.size, rootfs=args.rootfs)


def cmd_bootimg(args) -> None:
    from duolib import build
    build.boot_artifacts()


def cmd_build(args) -> None:
    from duolib import build, fetch, kernel, rootfs
    fetch.all()
    if not args.skip_kernel:
        if CFG.kernel.mode == "rocknix":
            kernel.build(jobs=args.jobs)
        else:
            if not (CACHE / "linux" / ".config").exists():
                kernel.configure()
            kernel.build(jobs=args.jobs)
    if not args.skip_rootfs:
        rootfs.build()
    else:
        build.boot_artifacts()
        util.warn("skipped rootfs; no SD image produced")
        return
    build.build(total_mb=args.size)


def cmd_adb(args) -> None:
    from duolib import device
    device.ensure_platform_tools()
    rest = [a for a in args.args if a != "--"]
    if not rest:
        util.die("usage: duo adb <pair|connect|devices|shell> ...")
    out = device.adb_raw(*rest, check=False)
    print(out)


def cmd_wireless(args) -> None:
    from duolib import device
    device.ensure_platform_tools()
    print()
    util.info("On the Duo Lite:")
    util.info("  Settings -> About tablet -> tap Build number 7 times")
    util.info("  Settings -> System -> Developer options -> Wireless debugging: On")
    util.info("  Tap 'Pair device with pairing code'. Keep that dialog open.")
    print()
    pair = input("  pairing endpoint (IP:PORT): ").strip()
    code = input("  6-digit pairing code: ").strip()
    if not pair or not code:
        util.die("pairing endpoint and code are required")
    print(device.adb_raw("pair", pair, code, check=False))
    print()
    util.info("Now use the IP:PORT shown on the main Wireless debugging screen")
    util.info("(it is usually different from the pairing port).")
    conn = input("  connect endpoint (IP:PORT): ").strip()
    if not conn:
        util.die("connect endpoint is required")
    out = device.adb_raw("connect", conn, check=False)
    print(out)
    if "connected" not in out.lower():
        util.warn("adb connect did not report success; check the IP/port and that both devices are on the same Wi-Fi")
    device.save_serial(conn)
    print()
    print(device.adb("devices", "-l"))
    util.ok(f"saved device serial {conn}")
    util.info("next: duo install --via-adb --with-abl")


def cmd_probe(args) -> None:
    from duolib import device
    device.probe()


def cmd_boot(args) -> None:
    from duolib import device
    img = args.image or (OUT / config.BOOTIMG_NAME)
    if not img.exists():
        util.die("no boot image yet. run: duo build (or duo bootimg)")
    device.boot(img)


def cmd_flash(args) -> None:
    from duolib import device
    img = OUT / config.IMAGE_NAME
    if not img.exists():
        util.die("no image yet. run: duo build")
    disk = args.disk
    if disk.isdigit():
        device.flash(img, int(disk), yes=args.yes)
    else:
        device.flash(img, disk, yes=args.yes)


def cmd_install(args) -> None:
    from duolib import install
    install.run(disk=args.disk, yes=args.yes, via_adb=args.via_adb, with_abl=args.with_abl)


def cmd_collect(args) -> None:
    from duolib import device
    device.collect(host=args.host)


def cmd_demo(args) -> None:
    script = config.REPO / "overlay/usr/local/lib/duo/duodeck.py"
    util.run([sys.executable, str(script), "demo"])


def cmd_selftest(args) -> None:
    import unittest
    tests = config.REPO / "tests"
    suite = unittest.defaultTestLoader.discover(str(tests))
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(0 if result.wasSuccessful() else 1)


if __name__ == "__main__":
    main()
