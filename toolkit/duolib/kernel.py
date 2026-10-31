"""Configure and build Retroid's 7.3 kernel for the Pocket Duo."""

from __future__ import annotations

import os
import shutil
from pathlib import Path

from . import util
from .builder import BuildEnv
from .config import CFG, CACHE, OUT, KERNEL_ARTIFACTS

ARCH = "arm64"
CROSS = "aarch64-linux-gnu-"

REQUIRED = [
    "CONFIG_DRM_MSM",
    "CONFIG_DRM_PANEL_VISIONOX_VTDR6130",
    "CONFIG_DRM_PANEL_ILITEK_IL97680A",
    "CONFIG_TOUCHSCREEN_EDT_FT5X06",
    "CONFIG_JOYSTICK_RSINPUT",
    "CONFIG_CLK_ELIZA_GCC",
    "CONFIG_PINCTRL_ELIZA",
    "CONFIG_INTERCONNECT_QCOM_ELIZA",
    "CONFIG_SCSI_UFS_QCOM",
    "CONFIG_MMC_SDHCI_MSM",
    "CONFIG_QCOM_PMIC_GLINK",
    "CONFIG_ATH12K",
    "CONFIG_SND_SOC_SC8280XP",
]


def _env() -> BuildEnv:
    env = BuildEnv()
    if not env.ready:
        util.die("no build environment.\n  " + env.install_hint())
    return env


def source() -> Path:
    src = CACHE / "linux"
    if not (src / "Makefile").exists():
        util.die("kernel source not fetched. run: duo fetch")
    return src


def configure(*, clean: bool = False) -> Path:
    if CFG.kernel.mode == "rocknix":
        util.info("using the ROCKNIX SM6115 kernel; nothing to configure")
        return CACHE / "rocknix"
    env = _env()
    src = source()
    util.banner("kernel configuration")
    OUT.mkdir(parents=True, exist_ok=True)
    KERNEL_ARTIFACTS.mkdir(parents=True, exist_ok=True)
    if clean and (src / ".config").exists():
        (src / ".config").unlink()
    env.run(["make", f"ARCH={ARCH}", f"CROSS_COMPILE={CROSS}", CFG.kernel.defconfig], cwd=src)
    frag = env.guest_path(CFG.kernel.fragment)
    env.run(["bash", "scripts/kconfig/merge_config.sh", "-m", ".config", frag], cwd=src)
    env.run(["make", f"ARCH={ARCH}", f"CROSS_COMPILE={CROSS}", "olddefconfig"], cwd=src)
    KERNEL_ARTIFACTS.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src / ".config", KERNEL_ARTIFACTS / "config")
    _check_config(src / ".config")
    util.ok(f"configuration written to {KERNEL_ARTIFACTS / 'config'}")
    return src


def _check_config(path: Path) -> None:
    text = path.read_text(errors="replace")
    values = {}
    for line in text.splitlines():
        if line.startswith("CONFIG_") and "=" in line:
            k, v = line.split("=", 1)
            values[k] = v
    bad = []
    for key in REQUIRED:
        v = values.get(key)
        if v in (None, "n"):
            bad.append(key)
    if bad:
        util.warn("these requested options did not stick: " + ", ".join(bad))
    else:
        util.ok("all required drivers enabled")


def build(*, jobs: int | None = None, clean: bool = False) -> dict[str, Path]:
    if CFG.kernel.mode == "rocknix":
        return _build_rocknix()
    env = _env()
    src = source()
    if not (src / ".config").exists():
        configure()
    if clean:
        env.run(["make", f"ARCH={ARCH}", f"CROSS_COMPILE={CROSS}", "clean"], cwd=src)
    try:
        import multiprocessing
        cores = multiprocessing.cpu_count()
    except Exception:  # noqa: BLE001
        cores = 8
    n = jobs or max(2, min(cores, 16))
    util.banner(f"building kernel ({n} jobs)")
    env.run(
        ["make", f"ARCH={ARCH}", f"CROSS_COMPILE={CROSS}", f"-j{n}", "Image", "modules"],
        cwd=src,
    )
    # Only the Duo DTB, not every board in the tree.
    p = env.run(
        ["make", f"ARCH={ARCH}", f"CROSS_COMPILE={CROSS}", f"qcom/{CFG.kernel.dtb}"],
        cwd=src, check=False,
    )
    if p.returncode != 0:
        env.run(["make", f"ARCH={ARCH}", f"CROSS_COMPILE={CROSS}", "dtbs"], cwd=src)
    util.banner("installing kernel artifacts")
    KERNEL_ARTIFACTS.mkdir(parents=True, exist_ok=True)
    image = src / "arch" / "arm64" / "boot" / "Image"
    dtb = src / "arch" / "arm64" / "boot" / "dts" / "qcom" / CFG.kernel.dtb
    if not image.exists():
        util.die("kernel Image was not produced")
    if not dtb.exists():
        util.die(f"dtb {CFG.kernel.dtb} was not produced")
    shutil.copy2(image, KERNEL_ARTIFACTS / "Image")
    shutil.copy2(dtb, KERNEL_ARTIFACTS / CFG.kernel.dtb)

    moddir = KERNEL_ARTIFACTS / "modules"
    if moddir.exists():
        shutil.rmtree(moddir)
    env.run([
        "make", f"ARCH={ARCH}", f"CROSS_COMPILE={CROSS}",
        f"INSTALL_MOD_PATH={env.guest_path(moddir)}", "modules_install",
    ], cwd=src)
    verm = (KERNEL_ARTIFACTS / "Image").stat().st_size
    nmod = len(list(moddir.rglob("*.ko")))
    util.ok(f"Image {util.human(verm)}, dtb, {nmod} modules")
    (KERNEL_ARTIFACTS / "VERSION").write_text(_version(src) + "\n")
    return {
        "image": KERNEL_ARTIFACTS / "Image",
        "dtb": KERNEL_ARTIFACTS / CFG.kernel.dtb,
        "modules": moddir,
    }


def _build_rocknix() -> dict[str, Path]:
    """Use ROCKNIX's proven SM6115 kernel, modules and DTB from the nightly."""
    from . import fetch
    base = fetch.rocknix()
    sysdir = fetch.rocknix_system(base)
    util.banner("installing ROCKNIX kernel artifacts")
    KERNEL_ARTIFACTS.mkdir(parents=True, exist_ok=True)
    image = base / "extract/target/KERNEL"
    dtb = base / "extract/3rdparty/bootloader/dtbs" / CFG.kernel.dtb
    if not image.exists():
        util.die("ROCKNIX KERNEL missing; run: duo fetch")
    if not dtb.exists():
        util.die(f"ROCKNIX dtb {CFG.kernel.dtb} missing")
    shutil.copy2(image, KERNEL_ARTIFACTS / "Image")
    shutil.copy2(dtb, KERNEL_ARTIFACTS / CFG.kernel.dtb)
    abl = base / "extract/3rdparty/bootloader/openabl/abl_signed-SM6115.elf"
    if abl.exists():
        shutil.copy2(abl, OUT / "abl_signed-SM6115.elf")

    mods = [p for p in (base / "modules").iterdir() if p.is_dir()] if (base / "modules").exists() else []
    if not mods:
        util.warn("no kernel modules in the ROCKNIX SYSTEM image; all drivers are built in")
        moddir = KERNEL_ARTIFACTS / "modules"
        moddir.mkdir(parents=True, exist_ok=True)
        ver = "7.2.0"
    else:
        moddir = KERNEL_ARTIFACTS / "modules"
        if moddir.exists():
            shutil.rmtree(moddir)
        ver = mods[0].name
        for m in mods:
            dst = moddir / "lib/modules" / m.name
            shutil.copytree(m, dst, symlinks=True)
    nmod = len(list(moddir.rglob("*.ko"))) if moddir.exists() else 0
    util.ok(f"Image {util.human(image.stat().st_size)}, dtb, {nmod} modules ({ver})")
    (KERNEL_ARTIFACTS / "VERSION").write_text(ver + "\n")
    return {
        "image": KERNEL_ARTIFACTS / "Image",
        "dtb": KERNEL_ARTIFACTS / CFG.kernel.dtb,
        "modules": moddir,
    }


def _version(src: Path) -> str:
    vals = {}
    for line in (src / "Makefile").read_text().splitlines()[:6]:
        if "=" in line:
            k, v = line.split("=", 1)
            vals[k.strip()] = v.strip()
    local = CFG.kernel.localversion
    return f"{vals.get('VERSION','?')}.{vals.get('PATCHLEVEL','?')}.{vals.get('SUBLEVEL','?')}{local}"
