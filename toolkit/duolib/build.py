"""Glue the kernel, initramfs, boot image and SD image together."""

from __future__ import annotations

import gzip
import shutil
from pathlib import Path

from . import bootimg, image, initramfs, util
from .config import CFG, OUT, BUILD, KERNEL_ARTIFACTS, BOOTIMG_NAME, IMAGE_NAME, ROOTFS_DIR

CMDLINE = (
    f"console=tty0 console=ttyMSM0,115200n8 root=LABEL={CFG.image.root_label} rw rootwait "
    "loglevel=7 panic=10 video=efifb:off gpt rdinit=/duo-init "
    f"boot=LABEL={CFG.image.boot_label} disk=LABEL={CFG.image.root_label} "
    "allow_mismatched_32bit_el0"
)


def kernel_version() -> str:
    p = KERNEL_ARTIFACTS / "VERSION"
    return p.read_text().strip() if p.exists() else "7.3.0-duo"


def boot_artifacts() -> dict[str, Path]:
    if not (KERNEL_ARTIFACTS / "Image").exists():
        util.die("kernel not built. run: duo kernel")
    util.banner("boot artifacts")
    initrd = initramfs.build(CMDLINE)
    boot_img = OUT / BOOTIMG_NAME
    bootimg.pack(bootimg.BootImage(
        kernel=(KERNEL_ARTIFACTS / "Image").read_bytes(),
        ramdisk=initrd.read_bytes(),
        dtb=(KERNEL_ARTIFACTS / CFG.kernel.dtb).read_bytes(),
        cmdline=CMDLINE,
        name="duolinux",
    ), boot_img)
    util.ok(f"boot image {boot_img.name} ({util.human(boot_img.stat().st_size)})")

    bootdir = BUILD / "boot"
    if bootdir.exists():
        shutil.rmtree(bootdir)
    (bootdir / "dtbs" / "qcom").mkdir(parents=True)
    (bootdir / "extlinux").mkdir(parents=True)
    (bootdir / "loader" / "entries").mkdir(parents=True)
    shutil.copy2(KERNEL_ARTIFACTS / "Image", bootdir / "KERNEL")
    shutil.copy2(KERNEL_ARTIFACTS / CFG.kernel.dtb, bootdir / "dtbs" / "qcom" / CFG.kernel.dtb)
    shutil.copy2(initrd, bootdir / "initrd.img")
    shutil.copy2(boot_img, bootdir / "boot.img")
    with gzip.open(bootdir / "Image.gz", "wb", compresslevel=6) as f:
        f.write((KERNEL_ARTIFACTS / "Image").read_bytes())

    conf = f"""LABEL DuoLinux
  LINUX /KERNEL
  FDT /dtbs/qcom/{CFG.kernel.dtb}
  INITRD /initrd.img
  APPEND {CMDLINE}
"""
    (bootdir / "extlinux" / "extlinux.conf").write_text(conf)
    (bootdir / "loader" / "entries" / "duolinux.conf").write_text(
        "title      DuoLinux\n"
        "linux      /KERNEL\n"
        "initrd     /initrd.img\n"
        f"options    {CMDLINE}\n"
    )
    util.ok(f"boot files -> {bootdir}")
    return {"bootdir": bootdir, "bootimg": boot_img, "initrd": initrd}


def build(total_mb: int | None = None, rootfs: Path | None = None) -> Path:
    rootfs = rootfs or ROOTFS_DIR
    if not (rootfs / "etc").is_dir():
        util.die("rootfs not built. run: duo rootfs")
    arts = boot_artifacts()
    if not (KERNEL_ARTIFACTS / "modules").exists():
        util.warn("kernel modules missing; Wi-Fi/audio may not load")
    total = total_mb or (CFG.image.boot_mb + CFG.image.root_mb + 8)
    out = OUT / IMAGE_NAME
    img = _assemble(arts["bootdir"], rootfs, out, total)
    (OUT / "SHA256SUMS").write_text(f"{util.sha256(img)}  {img.name}\n")
    util.ok(f"wrote {OUT / 'SHA256SUMS'}")
    return img


def _assemble(boot_dir: Path, root_dir: Path, out: Path, total_mb: int) -> Path:
    """Same as image.assemble but sizes the root partition to the filesystem."""
    import tempfile
    util.banner("assembling SD image")
    work = Path(tempfile.mkdtemp(prefix="duo-image-"))
    try:
        fat = work / "boot.vfat"
        ext = work / "root.ext4"
        image.make_fat(boot_dir, CFG.image.boot_mb, CFG.image.boot_label, fat)
        boot_start = image.ALIGN
        boot_sectors = CFG.image.boot_mb * 2048
        root_start = (boot_start + boot_sectors + image.ALIGN - 1) // image.ALIGN * image.ALIGN
        avail_mb = total_mb - (root_start // 2048) - 2
        if avail_mb < 1024:
            util.die("root filesystem would be smaller than 1 GiB")
        image.make_ext4(root_dir, avail_mb, CFG.image.root_label, ext)
        ext_sectors = (ext.stat().st_size + 511) // 512
        total_sectors = root_start + ext_sectors + 34
        out.parent.mkdir(parents=True, exist_ok=True)
        with out.open("wb") as f:
            f.truncate(total_sectors * 512)
        image.build_gpt(out, total_sectors, [
            {"start": boot_start, "end": boot_start + boot_sectors - 1,
             "type": CFG.image.esp_type, "name": CFG.image.boot_label},
            {"start": root_start, "end": root_start + ext_sectors - 1,
             "type": CFG.image.linux_type, "name": CFG.image.root_label},
        ])
        image.write_at(out, boot_start * 512, fat)
        image.write_at(out, root_start * 512, ext)
        util.ok(f"image {out.name}: {util.human(out.stat().st_size)}")
        return out
    finally:
        if work.exists():
            try:
                shutil.rmtree(work)
            except OSError:
                from . import host
                util.run([*host.sudo_prefix(), "rm", "-rf", str(work)], check=False)
