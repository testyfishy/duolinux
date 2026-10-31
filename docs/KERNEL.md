# Kernel

## Current: 7.2.11-nf

Stock ROCKNIX ships 7.2.0 from its own SM6115 tree. This device runs **7.2.11-nf**:
the same 79-patch device series, rebased onto the 7.2.11 stable tarball, with
netfilter enabled so Tailscale can run in TUN mode.

| Item | Value |
|---|---|
| Kernel | `7.2.11-nf` (`LOCALVERSION=-nf`) |
| Image on FAT | `KERNEL` = 14,080,370 bytes (gzip `Image.gz`) |
| Module trees | `/lib/modules/7.2.11-nf` (280 modules), plus `7.2.0` and `7.2.0-nf` kept |
| Rollback images | `KERNEL.720nf` (7.2.0-nf), `KERNEL.720` (original ROCKNIX 7.2.0) |
| Initrd | unchanged, contains **no modules** |
| Device tree | unchanged, `dtbs/qcom/sm6125-retroid-pocket-duo-lite.dtb` on FAT |

The initrd carries no modules, so every symbol needed to reach the rootfs must
stay built-in (`=y`). That is the hard gate before any install: any `=y` symbol
that becomes `=m` or unset is a no-boot bug.

## Why the kernel is not from the stable series directly

ROCKNIX's SM6115 patches were generated against 7.2.0. Eight of them fail to
apply to 7.2.11 with `patch -F3`/`git apply`. Plain re-application is not safe,
because a fuzz-applied display patch that lands in the wrong place still
compiles. The port therefore replays the series as commits and lets git do a
3-way merge per patch.

## How the port works

`toolkit/kernel/port-full.sh` then `toolkit/kernel/port-7.2.11.sh`:

1. Vanilla 7.2.0 tarball becomes tag `v7.2`.
2. Each patch (package dir first, then `devices/SM6115/patches/linux`) is applied
   as one commit: `git apply` first, `patch -p1 -F3` as fallback, so the branch
   reproduces the tree that actually built the working kernel.
3. The 7.2.11 tarball is imported as a parentless commit and the branch is
   `git rebase --onto` it. Every patch is then a real 3-way merge; only genuine
   semantic changes conflict.

### The one conflict: 0032 (bq256xx software JEITA)

7.2.11 had added, exactly where the patch inserts its JEITA init:

```c
/* Register after the power supplies so devm runs it first. */
ret = devm_add_action_or_reset(dev, bq256xx_charger_reset, bq);
...
usb_register_notifier(bq->usb2_phy, &bq->usb_nb);
usb_register_notifier(bq->usb3_phy, &bq->usb_nb);
```

Resolution keeps both, and the **order matters**:

```c
ret = devm_add_action_or_reset(dev, bq256xx_charger_reset, bq);   /* stable */
/* JEITA init here, before the notifiers */
INIT_DELAYED_WORK(&bq->jeita_work, bq256xx_jeita_work);
ret = devm_add_action_or_reset(dev, bq256xx_jeita_cleanup, bq);
if (ret) return ret;
/* then the notifiers */
```

Placing the JEITA init *before* `usb_register_notifier()` means a failing
`devm_add_action_or_reset` cannot leave notifiers registered against memory devm
is about to free. It also restores the patch's original position relative to
`bq256xx_irq_handler_thread()`, which does `mod_delayed_work(&bq->jeita_work, 0)`
on a VBUS change.

## Proving the port is faithful

- `verify-port-7.2.11.sh` - range-diff of the two series, and a commutation check
  over the 105 touched files comparing only `+`/`-` lines (context lines differ
  legitimately once the series' own code sits next to stable's hunk).
  Result: 78/79 patches identical, 105/105 files commute, 0 conflict markers.
- `compare-with-built-tree.sh` - the replayed 7.2.0 branch against the tree that
  built the running kernel, sha256 over ~77k source files: **0 differences**.
- `check-boot-critical.sh` - new `.config` vs the live `/proc/config.gz`:
  170 built-in symbols checked, 0 downgraded; 63 display symbols, 0 changed.
- `diff-config-7.2.11.sh` - `7.2.0-nf` -> `7.2.11-nf` adds only three upstream
  options (`ARM64_ERRATUM_3821522`, `ARM64_WORKAROUND_BROKEN_AMU_CONSTCNT`,
  `CC_OPT_INLINE_MEMSET`).

## Installing

`install-7.2.11.sh`, run on the device, modules first:

```
tar -C / -xzf modules-7.2.11-nf.tgz && depmod -a 7.2.11-nf
cp -p KERNEL KERNEL.720nf        # keep the previous working image
cp /tmp/KERNEL-7.2.11-nf KERNEL  # then swap
```

Modules go to their own tree, so the running kernel never sees them; the old
image and every module tree stay on disk. Rollback is
`cp KERNEL.720nf /mnt/boot/KERNEL` from the SD card rescue system.

## Verified after boot

- both panels connected (`DSI-1`, `DP-1`), backlight live
- 3/3 DPMS off/on cycles clean, 2 clean reboots, no new DRM errors
- `nft list ruleset`, `iptables`, `ip rule` all work; 18 netfilter modules
- charger hot-plug: `cc-state-change`, `vbus-change` and `attach-detach` IRQs
  counted on each transition, and charging confirmed under load: status
  `Charging`, +1.7 A, pack voltage rising, 0 errors in the JEITA path
- audio card `RetroidPocketDuoLite` present, 0 sound errors
- modem and adsp remoteprocs `running`
- 0 failed systemd units

## Quirks worth remembering

- **ABL passes the SD card's `APPEND` line** when both FAT partitions are
  labelled `ROCKNIX`, even when it boots the eMMC kernel. Harmless: `duo-init`
  ignores `root=` and resolves `LABEL=LINUXROOT` itself. Do not trust
  `/proc/cmdline` as evidence of which kernel or root is in use; check
  `findmnt -no SOURCE /` and `lsblk`.
- **The board DTB is not built here.** It lives on FAT and is loaded through
  `FDT` in `extlinux.conf`. The kernel swap does not touch it; the check that
  matters is that the new kernel's drivers still match its compatibles
  (`retroidpocket,duolite-hx83112a`, `retroidpocket,wl818s`, `qcom,sm6125-dp`,
  `qcom,sm6125-dpu`).
- **Mounting the FAT partition twice inherits `ro`.** A second mount of one block
  device shares the first mount's superblock; stale `/mnt/f` mounts made
  `/mnt/boot` read-only. Unmount every old mount before writing.
- `a630_sqe.fw` fails to load on every boot on both kernels (DPU writeback
  firmware, unused). Pre-existing, not a regression.
