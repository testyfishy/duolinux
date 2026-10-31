"""A build environment that works with or without root.

Preferred: native toolchain installed with apt.
Fallback: a proot'd Ubuntu rootfs in the user's cache. No sudo, no system changes.
"""

from __future__ import annotations

import os
import platform
import shlex
import shutil
from pathlib import Path

from . import host, util
from .config import CACHE, OUT, REPO

UBUNTU_BASE = "https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.3-base-amd64.tar.gz"
PROOT_URL = "https://github.com/proot-me/proot/releases/download/v5.5.0/proot"

APT_PACKAGES = [
    "build-essential", "gcc-aarch64-linux-gnu", "flex", "bison", "bc",
    "libssl-dev", "libelf-dev", "libncurses-dev", "rsync", "cpio", "kmod",
    "device-tree-compiler", "python3", "git", "ca-certificates", "zstd", "xz-utils",
    "dosfstools", "mtools", "e2fsprogs", "parted", "fdisk", "mmdebstrap",
    "qemu-user", "qemu-user-binfmt", "binfmt-support", "debian-archive-keyring",
    "squashfs-tools", "curl", "file", "alsa-utils",
]


class BuildEnv:
    def __init__(self) -> None:
        self.kind = "missing"
        self.proot = Path(os.environ.get("DUO_PROOT_BIN", CACHE / "tools" / "proot"))
        self.root = Path(os.environ.get("DUO_PROOT_ROOT", CACHE / "root-amd64"))
        self._detect()

    def _detect(self) -> None:
        if util.which("aarch64-linux-gnu-gcc") and util.which("make"):
            self.kind = "native"
            return
        # Development escape hatch: the environment used while bringing this up.
        legacy = Path.home() / "duo-build"
        if not self.proot.exists() and (legacy / "tools" / "proot").exists():
            self.proot = legacy / "tools" / "proot"
        if not self.root.exists() and (legacy / "root-amd64").exists():
            self.root = legacy / "root-amd64"
        if self.proot.exists() and (self.root / "usr" / "bin" / "aarch64-linux-gnu-gcc").exists():
            self.kind = "proot"

    @property
    def ready(self) -> bool:
        return self.kind != "missing"

    def describe(self) -> str:
        if self.kind == "native":
            return "native aarch64 cross toolchain"
        if self.kind == "proot":
            return f"rootless proot environment ({self.root})"
        return "not installed"

    # -- setup ---------------------------------------------------------
    def setup(self, *, rootless: bool = False) -> None:
        if self.ready:
            util.ok(f"build environment ready: {self.describe()}")
            return
        if not host.is_linux():
            util.die("setup must run inside Linux/WSL")
        if rootless or not host.can_sudo():
            self._setup_proot()
        else:
            self._setup_native()

    def _setup_native(self) -> None:
        util.banner("installing native build toolchain")
        util.info("apt will ask for your password once.")
        util.run(["sudo", "apt-get", "update"])
        util.run(["sudo", "apt-get", "install", "-y", *APT_PACKAGES])
        self._detect()
        if not self.ready:
            util.die("toolchain still missing after install")

    def _setup_proot(self) -> None:
        util.banner("setting up rootless build environment")
        if not host.userns_ok():
            util.die("user namespaces are blocked; run `duo setup` with sudo instead")
        CACHE.mkdir(parents=True, exist_ok=True)
        self.proot.parent.mkdir(parents=True, exist_ok=True)
        if not self.proot.exists():
            util.download(PROOT_URL, self.proot)
            self.proot.chmod(0o755)
        archive = CACHE / "ubuntu-base.tar.gz"
        if not self.root.exists():
            util.download(UBUNTU_BASE, archive)
            util.info("extracting base rootfs")
            util.extract_tar(archive, self.root)
        (self.root / "etc" / "resolv.conf").write_text("nameserver 1.1.1.1\n")
        util.info("installing packages inside proot (this takes a few minutes)")
        cmd = (
            "export DEBIAN_FRONTEND=noninteractive; "
            "apt-get update -qq && "
            "apt-get install -y --no-install-recommends " + " ".join(APT_PACKAGES)
        )
        self.run_shell(cmd)
        self._detect()
        if not self.ready:
            util.die("proot environment did not produce a compiler")

    # -- command wrapping ---------------------------------------------
    def guest_path(self, path: Path | str) -> str:
        p = Path(path).resolve()
        for base, guest in ((CACHE, "/cache"), (OUT, "/out"), (REPO, "/host")):
            try:
                rel = p.relative_to(base.resolve())
                return str(Path(guest) / rel)
            except ValueError:
                continue
        return str(p)

    def wrap(self, cmd: list[str], *, cwd: Path | None = None) -> list[str]:
        if self.kind == "native":
            return cmd
        args = [
            str(self.proot), "-0", "-r", str(self.root),
            "-b", "/proc", "-b", "/dev", "-b", "/sys",
            "-b", f"{CACHE}:/cache", "-b", f"{OUT}:/out", "-b", f"{REPO}:/host",
        ]
        if cwd:
            args += ["-w", self.guest_path(cwd)]
        return args + cmd

    def run(self, cmd: list[str], *, cwd: Path | None = None, check: bool = True):
        return util.run(self.wrap(cmd, cwd=cwd), check=check)

    def run_shell(self, script: str, *, cwd: Path | None = None) -> None:
        util.run(self.wrap(["bash", "-lc", script], cwd=cwd))

    def capture(self, cmd: list[str], *, cwd: Path | None = None) -> str:
        p = util.run(self.wrap(cmd, cwd=cwd), quiet=True, check=False)
        return (p.stdout or "").strip()

    def install_hint(self) -> str:
        if self.kind == "native":
            return ""
        return "run `duo setup --rootless` (no sudo) or `duo setup` (uses sudo)"
