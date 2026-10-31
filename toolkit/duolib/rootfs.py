"""Build the Debian arm64 root filesystem and install the Duo overlay."""

from __future__ import annotations

import re
import shutil
from pathlib import Path

from . import fetch, host, util
from .build import kernel_version
from .config import CFG, CACHE, ROOTFS_DIR, KERNEL_ARTIFACTS


def packages() -> list[str]:
    out = []
    for line in CFG.rootfs.packages_file.read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            out.append(line)
    return out


def _mmdebstrap() -> str | None:
    return util.which("mmdebstrap")


def build(*, force: bool = False) -> Path:
    if force and ROOTFS_DIR.exists():
        shutil.rmtree(ROOTFS_DIR)
    if (ROOTFS_DIR / "etc" / "os-release").exists() and (ROOTFS_DIR / "var/lib/duo/rootfs.done").exists():
        util.ok(f"rootfs already built at {ROOTFS_DIR}")
        return ROOTFS_DIR
    if not host.is_linux():
        util.die("rootfs must be built on Linux/WSL")
    if host.euid() != 0 and not util.which("sudo"):
        util.die("rootfs build needs root (sudo) for chroot")
    if not _mmdebstrap():
        util.die("mmdebstrap is missing. run: duo setup --native")
    if host.euid() != 0 and not Path("/proc/sys/fs/binfmt_misc/qemu-aarch64").exists():
        util.info("enabling qemu-aarch64 binfmt")
        util.run(["sudo", "update-binfmts", "--enable", "qemu-aarch64"], check=False)

    util.banner("building Debian arm64 rootfs")
    ROOTFS_DIR.parent.mkdir(parents=True, exist_ok=True)
    prefix = host.sudo_prefix()
    if ROOTFS_DIR.exists():
        util.run([*prefix, "rm", "-rf", str(ROOTFS_DIR)])
    pkgs = ",".join(packages())
    cmd = [
        *prefix, "mmdebstrap",
        "--arch", CFG.rootfs.arch,
        "--variant", "minbase",
        "--components", "main,contrib,non-free-firmware",
        "--include", pkgs,
        "--aptopt", "Acquire::Retries=5",
        "--aptopt", "Acquire::http::Timeout=30",
        "--aptopt", 'Acquire::AllowInsecureRepositories "true"',
        "--aptopt", 'Apt::Get::AllowUnauthenticated "true"',
        CFG.rootfs.suite, str(ROOTFS_DIR), CFG.rootfs.mirror,
    ]
    util.run(cmd)

    _install_overlay()
    _install_kernel()
    _install_firmware()
    _install_tailscale()
    _run_setup()
    (ROOTFS_DIR / "var/lib/duo").mkdir(parents=True, exist_ok=True)
    (ROOTFS_DIR / "var/lib/duo/rootfs.done").write_text("ok\n")
    util.ok(f"rootfs ready: {ROOTFS_DIR}")
    return ROOTFS_DIR


def _sudo(*args: str) -> None:
    util.run([*host.sudo_prefix(), *args])


def _install_overlay() -> None:
    util.info("copying overlay")
    _sudo("cp", "-a", f"{CFG.rootfs.overlay}/.", f"{ROOTFS_DIR}/")
    # Files coming from Windows/macOS can be world-writable. systemd ignores
    # world-writable units, and sshd dislikes loose config modes.
    for rel in (
        "etc/systemd/system", "etc/sway", "etc/duo", "etc/ssh/sshd_config.d",
        "etc/udev/rules.d", "etc/NetworkManager/conf.d", "etc/modules-load.d",
        "etc/default", "etc/skel", "usr/local/bin", "usr/local/lib/duo",
    ):
        p = ROOTFS_DIR / rel
        if p.exists():
            _sudo("chmod", "-R", "u+rwX,go+rX,go-w", str(p))
    for rel in ("etc/motd",):
        p = ROOTFS_DIR / rel
        if p.exists():
            _sudo("chmod", "644", str(p))
    # Windows/macOS copies arrive owned by uid 1000. systemd wants root-owned
    # units; keep only the user's home and duo.conf owned by the duo user.
    for rel in (
        "etc/systemd/system", "etc/sway", "etc/ssh", "etc/udev",
        "etc/NetworkManager", "etc/modules-load.d", "etc/default", "etc/skel",
        "etc/duo", "usr/local/bin", "usr/local/lib/duo",
    ):
        p = ROOTFS_DIR / rel
        if p.exists():
            _sudo("chown", "-R", "0:0", str(p))
    _sudo("chmod", "755", f"{ROOTFS_DIR}/usr/local/bin")
    _sudo("chmod", "644", f"{ROOTFS_DIR}/etc/duo/tailscale.authkey.example") if (ROOTFS_DIR / "etc/duo/tailscale.authkey.example").exists() else None
    _sudo("chown", "1000:1000", str(ROOTFS_DIR / "etc/duo/duo.conf"))
    _sudo("chmod", "600", str(ROOTFS_DIR / "etc/duo/duo.conf"))
    _sudo("chown", "-R", "1000:1000", str(ROOTFS_DIR / "home/duo"))
    _sudo("chmod", "700", str(ROOTFS_DIR / "home/duo"))


def _install_kernel() -> None:
    ver = kernel_version()
    src = KERNEL_ARTIFACTS / "modules" / "lib" / "modules" / ver
    if not src.exists():
        util.warn(f"kernel modules for {ver} not found; build the kernel first")
        return
    util.info(f"installing kernel modules {ver}")
    dst = ROOTFS_DIR / "lib" / "modules"
    _sudo("mkdir", "-p", str(dst))
    _sudo("cp", "-a", str(src), str(dst / ver))
    _sudo("chown", "-R", "0:0", str(dst / ver))


def _install_firmware() -> None:
    if CFG.firmware.mode == "rocknix":
        fw = CACHE / "rocknix" / "firmware"
        ucm = CACHE / "rocknix" / "ucm2"
        if fw.exists():
            util.info("installing ROCKNIX firmware")
            dst = ROOTFS_DIR / "usr/lib/firmware"
            _sudo("mkdir", "-p", str(dst))
            _sudo("rsync", "-a", f"{fw}/", f"{dst}/")
            _sudo("chown", "-R", "0:0", str(dst))
        if ucm.exists():
            util.info("installing ROCKNIX UCM")
            dst = ROOTFS_DIR / "usr/share/alsa/ucm2"
            _sudo("mkdir", "-p", str(dst))
            _sudo("rsync", "-a", f"{ucm}/", f"{dst}/")
            _sudo("chown", "-R", "0:0", str(dst))
        return
    fw = CACHE / "firmware"
    if not fw.exists():
        util.warn("no firmware cache; run: duo fetch")
        return
    util.info("installing firmware blobs")
    dst = ROOTFS_DIR / "usr/lib/firmware"
    _sudo("mkdir", "-p", str(dst))
    _sudo("cp", "-a", f"{fw}/.", f"{dst}/")
    audio = CACHE / "audio"
    if (audio / "ucm2").exists():
        ucm = ROOTFS_DIR / "usr/share/alsa/ucm2"
        _sudo("mkdir", "-p", str(ucm))
        _sudo("cp", "-a", f"{audio}/ucm2/.", f"{ucm}/")
    topo = audio / "topology"
    if topo.exists():
        _sudo("mkdir", "-p", str(dst / "qcom/eliza"))
        _sudo("mkdir", "-p", str(dst / "qcom/eliza/retroidpocket/rpduo"))
        for f in topo.glob("*.bin"):
            _sudo("cp", "-a", str(f), str(dst / "qcom/eliza" / f.name))
            _sudo("cp", "-a", str(f), str(dst / "qcom/eliza/retroidpocket/rpduo" / f.name))
            _sudo("cp", "-a", str(f), str(dst / "qcom" / f.name))


def _install_tailscale() -> None:
    deb = fetch.tailscale()
    if not deb:
        util.warn("tailscale package not fetched; install it later with apt")
        return
    util.info("installing tailscale")
    tmp = ROOTFS_DIR / "tmp" / "tailscale.deb"
    _sudo("cp", str(deb), str(tmp))
    util.run([*host.sudo_prefix(), "chroot", str(ROOTFS_DIR), "dpkg", "-i", "/tmp/tailscale.deb"], check=False)
    util.run([*host.sudo_prefix(), "chroot", str(ROOTFS_DIR), "apt-get", "-f", "install", "-y"], check=False)
    _sudo("rm", "-f", str(tmp))


def _run_setup() -> None:
    util.info("running setup hooks")
    script = CFG.rootfs.packages_file.parent / "setup.sh"
    _sudo("cp", str(script), str(ROOTFS_DIR / "tmp" / "setup.sh"))
    env = {
        "DUO_USER": CFG.rootfs.user,
        "DUO_PASSWORD": CFG.rootfs.password,
        "DUO_HOSTNAME": CFG.rootfs.hostname,
        "DUO_TIMEZONE": "Europe/London",
        "DUO_ROOT_LABEL": CFG.image.root_label,
    }
    args = [*host.sudo_prefix(), "chroot", str(ROOTFS_DIR), "/usr/bin/env"]
    args += [f"{k}={v}" for k, v in env.items()]
    args += ["/bin/bash", "/tmp/setup.sh"]
    util.run(args)
