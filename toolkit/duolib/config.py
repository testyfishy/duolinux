"""Paths, defaults and device profiles for DuoLinux."""

from __future__ import annotations

import json
import os
import sys
from dataclasses import dataclass, field
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
VERSION = "0.2.0"
CODENAME = "Duo Lite"


def _cache_root() -> Path:
    override = os.environ.get("DUO_CACHE")
    if override:
        return Path(override).expanduser()
    if os.name == "nt":
        base = Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData" / "Local"))
    else:
        base = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
    return base / "duolinux"


CACHE = _cache_root()
OUT = Path(os.environ.get("DUO_OUT", REPO / "out")).expanduser()
BUILD = CACHE / "build"


@dataclass
class KernelCfg:
    # "rocknix": use ROCKNIX's proven SM6115 kernel/modules/DTB from a nightly.
    # "retroid": build Retroid's Eliza tree (flagship Duo; not the Lite).
    mode: str = "rocknix"
    dtb: str = "sm6125-retroid-pocket-duo-lite.dtb"
    localversion: str = "-duo"
    fragment: Path = REPO / "configs" / "kernel" / "duol.fragment"
    config: Path = REPO / "configs" / "kernel" / "duol.config"
    # source build (flagship / future)
    repo: str = "https://github.com/RetroidPocket/linux.git"
    branch: str = "retroidpocket/v7.3"
    defconfig: str = "defconfig"
    # ROCKNIX nightly for the Lite
    rocknix_version: str = "20261029"
    rocknix_url: str = (
        "https://github.com/ROCKNIX/distribution-nightly/releases/download/"
        "nightly-20261029/ROCKNIX-SM6115.aarch64-20261029.tar"
    )


@dataclass
class RootfsCfg:
    suite: str = "trixie"
    mirror: str = "https://deb.debian.org/debian"
    arch: str = "arm64"
    hostname: str = "duo"
    user: str = "duo"
    password: str = "duo"
    packages_file: Path = REPO / "configs" / "rootfs" / "packages.list"
    overlay: Path = REPO / "overlay"


@dataclass
class ImageCfg:
    # ROCKNIX ABL looks for the layout it ships. These labels match it.
    boot_label: str = "ROCKNIX"
    root_label: str = "STORAGE"
    boot_mb: int = 512
    root_mb: int = 7168
    esp_type: str = "C12A7328-F81F-11D2-BA4B-00A0C93EC93B"
    linux_type: str = "0FC63DAF-8483-4772-8E79-3D69D8477DE4"


@dataclass
class FirmwareCfg:
    mode: str = "rocknix"
    vendor_repo: str = "RPQ7790Dev/proprietary_vendor_retroidpocket_RPDuo"
    vendor_branch: str = "lineage-24.0"
    common_repo: str = "RPQ7790Dev/proprietary_vendor_retroidpocket_cq7790s-common"
    common_branch: str = "lineage-24.0"
    topology_repo: str = "https://github.com/RetroidPocket/audioreach-topology.git"
    topology_branch: str = "retroidpocket/v1.0.5"
    ucm_repo: str = "https://github.com/RetroidPocket/alsa-ucm-conf.git"
    ucm_branch: str = "retroidpocket/v1.2.16"


@dataclass
class Settings:
    device: str = "duol"
    soc: str = "sm6125"
    codename: str = "duol"
    kernel: KernelCfg = field(default_factory=KernelCfg)
    rootfs: RootfsCfg = field(default_factory=RootfsCfg)
    image: ImageCfg = field(default_factory=ImageCfg)
    firmware: FirmwareCfg = field(default_factory=FirmwareCfg)

    @classmethod
    def load(cls) -> "Settings":
        s = cls()
        s.device = os.environ.get("DUO_DEVICE", s.device)
        override = REPO / "duo.json"
        if override.exists():
            data = json.loads(override.read_text())
            for key, val in data.items():
                if hasattr(s, key) and isinstance(val, dict):
                    obj = getattr(s, key)
                    for k, v in val.items():
                        if hasattr(obj, k):
                            setattr(obj, k, v)
                elif hasattr(s, key):
                    setattr(s, key, val)
        s._apply_profile()
        return s

    def _apply_profile(self) -> None:
        if self.device in ("rpduo", "duo", "eliza"):
            self.device = "rpduo"
            self.soc = "q7790"
            self.codename = "eliza"
            self.kernel.mode = "retroid"
            self.kernel.repo = "https://github.com/RetroidPocket/linux.git"
            self.kernel.branch = "retroidpocket/v7.3"
            self.kernel.dtb = "eliza-retroidpocket-rpduo.dtb"
            self.kernel.fragment = REPO / "configs" / "kernel" / "duo.fragment"
            self.image.boot_label = "DUOBOOT"
            self.image.root_label = "DUOROOT"
            self.firmware.mode = "retroid"
        else:
            self.device = "duol"
            self.soc = "sm6125"
            self.codename = "duol"
            self.kernel.mode = "rocknix"
            self.kernel.dtb = "sm6125-retroid-pocket-duo-lite.dtb"
            self.kernel.fragment = REPO / "configs" / "kernel" / "duol.fragment"
            self.image.boot_label = "ROCKNIX"
            self.image.root_label = "STORAGE"
            self.firmware.mode = "rocknix"

    def ensure_dirs(self) -> None:
        for p in (CACHE, OUT, BUILD):
            p.mkdir(parents=True, exist_ok=True)

    @property
    def is_lite(self) -> bool:
        return self.device == "duol"


CFG = Settings.load()

IMAGE_NAME = f"duolinux-{CFG.device}.img"
BOOTIMG_NAME = f"boot-duolinux-{CFG.device}.img"
KERNEL_ARTIFACTS = OUT / "kernel"
ROOTFS_DIR = BUILD / "rootfs"
ROOTFS_TAR = OUT / f"rootfs-duolinux-{CFG.device}.tar.zst"
