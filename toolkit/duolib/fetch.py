"""Fetch kernel sources, firmware blobs and audio configuration."""

from __future__ import annotations

import json
import re
import shutil
import tarfile
from pathlib import Path

from . import util
from .config import CFG, CACHE

SRC = CACHE / "src"
FW = CACHE / "firmware"
FW_TARGET = "qcom/eliza/retroidpocket/rpduo"


def _tarball(repo: str, branch: str, dest: Path) -> Path:
    """Download and extract a GitHub branch tarball (no git required)."""
    name = repo.split("/")[-1]
    archive = SRC / f"{name}-{branch.replace('/', '_')}.tar.gz"
    if not dest.exists():
        url = f"https://codeload.github.com/{repo}/tar.gz/refs/heads/{branch}"
        util.download(url, archive, quiet=False)
        util.info(f"extracting {name}")
        with tarfile.open(archive) as t:
            t.extractall(SRC)
        roots = [p for p in SRC.iterdir() if p.is_dir() and p.name.startswith(name)]
        if not roots:
            util.die(f"unexpected archive layout for {repo}")
        if dest.exists():
            shutil.rmtree(dest)
        roots[0].rename(dest)
    return dest


def kernel(*, force: bool = False) -> Path:
    dest = CACHE / "linux"
    util.banner("kernel source")
    if force and dest.exists():
        shutil.rmtree(dest)
    if not (dest / ".git").exists():
        util.run([
            "git", "clone", "--depth", "1", "--branch", CFG.kernel.branch,
            CFG.kernel.repo, str(dest),
        ])
    else:
        util.info(f"updating {dest}")
        util.run(["git", "-C", str(dest), "fetch", "--depth", "1", "origin", CFG.kernel.branch])
        util.run(["git", "-C", str(dest), "reset", "--hard", "FETCH_HEAD"])
    ver = _kernelversion(dest)
    util.ok(f"kernel {ver or '?'} at {dest}")
    return dest


def _kernelversion(dest: Path) -> str:
    vals = {}
    try:
        for line in (dest / "Makefile").read_text().splitlines()[:6]:
            if "=" in line:
                k, v = line.split("=", 1)
                vals[k.strip()] = v.strip()
    except OSError:
        return ""
    return f"{vals.get('VERSION','?')}.{vals.get('PATCHLEVEL','?')}.{vals.get('SUBLEVEL','?')}"


def _copy(src: Path, dst: Path, *, rename: str | None = None) -> None:
    if not src.exists():
        return
    dst.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst / (rename or src.name))


def _qualcomm_split(src_dir: Path, base: str, dst: Path) -> bool:
    """Convert Android .mdt + .bNN into the .mbn + .bNN layout the kernel wants."""
    mdt = src_dir / f"{base}.mdt"
    if not mdt.exists():
        return False
    dst.mkdir(parents=True, exist_ok=True)
    shutil.copy2(mdt, dst / f"{base}.mbn")
    for f in src_dir.glob(f"{base}.b[0-9][0-9]"):
        shutil.copy2(f, dst / f.name)
    return True


def firmware() -> Path:
    util.banner("firmware")
    marker = FW / ".complete"
    if marker.exists():
        util.ok(f"firmware cached at {FW}")
        return FW
    FW.mkdir(parents=True, exist_ok=True)

    duo = _tarball(CFG.firmware.vendor_repo, CFG.firmware.vendor_branch, SRC / "vendor-duo")
    common = _tarball(CFG.firmware.common_repo, CFG.firmware.common_branch, SRC / "vendor-common")

    duo_fw = duo / "proprietary" / "vendor" / "firmware"
    common_fw = common / "proprietary" / "vendor" / "firmware"
    target = FW / FW_TARGET
    target.mkdir(parents=True, exist_ok=True)

    copied: list[str] = []
    missing: list[str] = []

    for base in ("adsp", "adsp_dtb", "cdsp", "cdsp_dtb", "wpss", "wpss_dtb"):
        if _qualcomm_split(duo_fw, base, target) or _qualcomm_split(common_fw, base, target):
            copied.append(f"{base}.mbn")
        else:
            missing.append(base)

    # GPU: the DTS asks for gen71700_zap.mbn; the public vendor tree ships
    # gen70e00_zap.mbn plus gen71700_gmu.bin. Try the vendor pair and note it.
    for src, name in (
        (common_fw / "gen70e00_zap.mbn", "gen71700_zap.mbn"),
        (common_fw / "gen71700_gmu.bin", "gen71700_gmu.bin"),
        (common_fw / "gen70e00_sqe.fw", "gen71700_sqe.fw"),
        (duo_fw / "aw883xx_acf.bin", "aw883xx_acf.bin"),
        (duo_fw / "mcuapp_firmware.bin", "mcuapp_firmware.bin"),
    ):
        if src.exists():
            _copy(src, target, rename=name)
            copied.append(name)

    # A few generic Qualcomm bits used by USB / video.
    for name in ("qps615_fw.bin", "vpu30_2v.mbn"):
        if (common_fw / name).exists():
            _copy(common_fw / name, FW / "qcom", rename=name)

    manifest = {
        "target": FW_TARGET,
        "copied": sorted(set(copied)),
        "missing": sorted(set(missing)),
        "note": (
            "cdsp/wpss if missing may live in the Android dsp.img partition; "
            "display/touch/USB/storage do not need them. Audio needs adsp + topology."
        ),
    }
    (FW / "MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n")
    if missing:
        util.warn("missing firmware: " + ", ".join(sorted(set(missing))))
    util.ok(f"{len(set(copied))} firmware files -> {target}")
    marker.write_text("ok\n")
    return FW


def audio() -> Path:
    """Fetch Retroid's UCM config and audioreach topology sources."""
    util.banner("audio configuration")
    topo = _tarball("RetroidPocket/audioreach-topology", CFG.firmware.topology_branch, SRC / "topology")
    ucm = _tarball("RetroidPocket/alsa-ucm-conf", CFG.firmware.ucm_branch, SRC / "ucm")

    out = CACHE / "audio"
    out.mkdir(parents=True, exist_ok=True)

    # UCM: copy the whole ucm2 tree; it is small and self-contained.
    ucm_src = ucm / "ucm2"
    if ucm_src.exists():
        dst = out / "ucm2"
        if dst.exists():
            shutil.rmtree(dst)
        shutil.copytree(ucm_src, dst)
        util.ok(f"UCM -> {dst}")

    # Topology: build the Eliza m4 file directly (m4 + alsatplg), no cmake needed.
    bins = list(topo.rglob("*.bin"))
    m4file = topo / "ELIZA-RetroidPocket-I2S.m4"
    if not bins and m4file.exists():
        util.info("building ELIZA topology (m4 + alsatplg)")
        try:
            from .builder import BuildEnv
            env = BuildEnv()
            outdir = CACHE / "audio" / "topology"
            outdir.mkdir(parents=True, exist_ok=True)
            if env.ready:
                conf = env.guest_path(outdir / "ELIZA-RetroidPocket-I2S.conf")
                binp = env.guest_path(outdir / "ELIZA-RetroidPocket-I2S-tplg.bin")
                script = (
                    f"mkdir -p {env.guest_path(outdir)} && "
                    f"m4 -I {env.guest_path(topo)} {env.guest_path(m4file)} > {conf} && "
                    f"alsatplg -c {conf} -o {binp}"
                )
                env.run_shell(script)
            else:
                util.run(
                    f"m4 -I {topo} {m4file} > {outdir}/ELIZA-RetroidPocket-I2S.conf && "
                    f"alsatplg -c {outdir}/ELIZA-RetroidPocket-I2S.conf "
                    f"-o {outdir}/ELIZA-RetroidPocket-I2S-tplg.bin",
                    check=False,
                )
        except Exception as ex:  # noqa: BLE001
            util.warn(f"topology build failed: {ex}")
        bins = list(outdir.glob("*.bin"))
    tdir = out / "topology"
    tdir.mkdir(exist_ok=True)
    for b in bins:
        if b.parent == tdir:
            continue
        shutil.copy2(b, tdir / b.name)
    if bins:
        util.ok(f"{len(bins)} topology file(s) -> {tdir}")
    else:
        util.warn("no prebuilt topology found; audio may be silent until one is built")
    return out


def all(*, force: bool = False) -> None:
    CFG.ensure_dirs()
    SRC.mkdir(parents=True, exist_ok=True)
    if CFG.kernel.mode == "rocknix":
        base = rocknix()
        rocknix_system(base)
    else:
        kernel(force=force)
        firmware()
        audio()
    tailscale()


ROCKNIX = CACHE / "rocknix"


def rocknix() -> Path:
    """Download and extract the ROCKNIX SM6115 nightly (Lite hardware base)."""
    util.banner("ROCKNIX SM6115 hardware base")
    ROCKNIX.mkdir(parents=True, exist_ok=True)
    tar = ROCKNIX / "ROCKNIX-SM6115.tar"
    if not tar.exists():
        util.download(CFG.kernel.rocknix_url, tar)
    extract = ROCKNIX / "extract"
    extract.mkdir(parents=True, exist_ok=True)
    want = {
        "target/KERNEL",
        "target/SYSTEM",
        f"3rdparty/bootloader/dtbs/{CFG.kernel.dtb}",
        "3rdparty/bootloader/openabl/abl_signed-SM6115.elf",
        "3rdparty/bootloader/openabl/backup_abl.sh",
        "3rdparty/bootloader/openabl/flash_abl.sh",
        "3rdparty/bootloader/openabl/restore_backup_abl.sh",
        "3rdparty/bootloader/loader/entries/rocknix.conf",
    }
    with tarfile.open(tar) as t:
        names = t.getnames()
        prefix = next(n for n in names if n.endswith("/target") and n.count("/") == 1) + "/"
        done = {str(p.relative_to(extract)) for p in extract.rglob("*") if p.is_file()}
        for m in t.getmembers():
            if not m.name.startswith(prefix):
                continue
            rel = m.name[len(prefix):]
            if rel in want and rel not in done:
                m.name = rel
                t.extract(m, extract)
                util.info(f"extracted {rel}")
    if not (extract / "target/KERNEL").exists():
        util.die("ROCKNIX archive did not contain target/KERNEL")
    return ROCKNIX


def rocknix_system(base: Path | None = None) -> Path:
    """Pull modules, firmware and UCM out of the ROCKNIX squashfs once."""
    base = base or ROCKNIX
    system = base / "system"
    mods = system / "usr/lib/kernel-overlays/base/lib/modules"
    if mods.exists():
        _stage_rocknix_assets(base, system)
        return system
    squash = base / "extract/target/SYSTEM"
    if not squash.exists():
        util.die("ROCKNIX SYSTEM squashfs missing; run: duo fetch")
    util.banner("extracting ROCKNIX SYSTEM (modules, firmware, UCM)")
    from .builder import BuildEnv
    env = BuildEnv()
    if not env.ready:
        util.die("a build environment is required to extract squashfs. run: duo setup")
    env.run([
        "unsquashfs", "-f", "-d", env.guest_path(system), env.guest_path(squash),
        "usr/lib/kernel-overlays/base/lib/modules",
        "usr/lib/kernel-overlays/base/lib/firmware",
        "usr/share/alsa/ucm2",
    ])
    _stage_rocknix_assets(base, system)
    return system


def _stage_rocknix_assets(base: Path, system: Path) -> None:
    mods = system / "usr/lib/kernel-overlays/base/lib/modules"
    if mods.exists() and not (base / "modules").exists():
        shutil.copytree(mods, base / "modules", symlinks=True)
    fw = system / "usr/lib/kernel-overlays/base/lib/firmware"
    if fw.exists() and not (base / "firmware").exists():
        shutil.copytree(fw, base / "firmware")
    ucm = system / "usr/share/alsa/ucm2"
    if ucm.exists() and not (base / "ucm2").exists():
        shutil.copytree(ucm, base / "ucm2")


def tailscale() -> Path | None:
    """Fetch the newest arm64 tailscale .deb from Tailscale's own repo."""
    util.banner("tailscale")
    debs = CACHE / "debs"
    debs.mkdir(parents=True, exist_ok=True)
    idx = debs / "tailscale-Packages"
    url = "https://pkgs.tailscale.com/stable/debian/dists/trixie/main/binary-arm64/Packages"
    if not idx.exists():
        util.download(url, idx)
    text = idx.read_text(errors="replace")
    best = None
    for stanza in text.split("\n\n"):
        if not re.search(r"^Package: tailscale$", stanza, re.M):
            continue
        ver = re.search(r"^Version: (.+)$", stanza, re.M)
        fn = re.search(r"^Filename: (.+)$", stanza, re.M)
        if not (ver and fn):
            continue
        key = tuple(int(x) for x in re.findall(r"\d+", ver.group(1))[:4])
        if best is None or key > best[0]:
            best = (key, ver.group(1), fn.group(1))
    if not best:
        util.warn("could not find a tailscale arm64 package")
        return None
    _, ver, filename = best
    deb = debs / Path(filename).name
    if not deb.exists():
        util.download("https://pkgs.tailscale.com/stable/debian/" + filename, deb)
    util.ok(f"tailscale {ver} ({util.human(deb.stat().st_size)})")
    return deb
