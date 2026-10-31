# SM6115 / Retroid Pocket Duo Lite — series rebased onto Linux 7.2.11

This is the kernel patch series this device actually runs, rebased from the
7.2.0 base it was written against onto stable **7.2.11**, plus the one conflict
resolution that required a human decision.

It is published so the work is not lost and so a future stable kernel can be
targeted without starting over. It is **not** a mainline submission: most
patches were written by other people, and several are downstream designs that
upstream will not take in this form (see *Upstream status*).

## Contents

| File | |
|---|---|
| `0001`–`0079` | the series, cleanly applicable **in order** onto vanilla 7.2.11 |
| `SERIES` | index with the author of each patch and its provenance |
| this file | how to apply, build, install and test |

Base: vanilla `7.2.11` tarball from kernel.org.
Source: ROCKNIX `projects/ROCKNIX/devices/SM6115/patches/linux`, snapshot
2026-10-29. The series was generated against 7.2.0 and 8 of the 79 do not apply
to 7.2.11 with `patch -F3` — two of them the panel and its power sequence —
which is why the rebase below exists.

## What was changed to get here

Only one patch needed judgement; the other 78 have identical range-diff output
to their 7.2.0 form.

**`0032` bq256xx software JEITA.** 7.2.11 added a deferred reset action and USB
notifier registration exactly where this patch inserts its JEITA init. Both are
kept now, in this order:

```c
ret = devm_add_action_or_reset(dev, bq256xx_charger_reset, bq);  /* stable */
/* JEITA init: the position the patch used on 7.2.0 */
INIT_DELAYED_WORK(&bq->jeita_work, bq256xx_jeita_work);
ret = devm_add_action_or_reset(dev, bq256xx_jeita_cleanup, bq);
if (ret)
        return ret;
/* then the notifiers */
usb_register_notifier(bq->usb2_phy, &bq->usb_nb);
usb_register_notifier(bq->usb3_phy, &bq->usb_nb);
```

The order matters twice: a failing `devm_add_action_or_reset` cannot leave the
notifiers registered against memory that devm is about to free, and the JEITA
init stays ahead of `bq256xx_irq_handler_thread()`, which does
`mod_delayed_work(&bq->jeita_work, 0)` on a VBUS change.

## Applying to a newer stable kernel

```sh
git clone --filter=blob:none --no-checkout https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
cd linux
git checkout vX.Y.Z            # the target stable
git switch -c work

git am -3 /path/to/7.2.11/*.patch     # -3 lets git use the blob ids in the patches
```

`git am -3` is the important part: plain `git apply` fails on context that
stable moved, and `patch -F3` may land a hunk in the wrong place while still
compiling. If a patch conflicts:

1. `git log --oneline <old-base>..<new-base> -- <file>` to see what stable did.
2. Keep stable's change, put the patch's hunk back on top of it, adapt
   signatures if they moved.
3. Never revert a stable fix to make a patch apply.

Prove the result before building:

```sh
# each patch must still say the same thing
git range-diff v7.2.11..work-old vX.Y.Z..work-new

# stable's changes and the series' changes must compose identically either way
F=$(git diff --name-only v7.2.11 work-old)
diff <(git diff v7.2.11 vX.Y.Z -- $F) <(git diff work-old work-new -- $F)
```

Compare only added/removed lines for the second check; context lines legitimately
differ once the series' own code sits next to stable's hunk.

## Building

```sh
cp <device>/linux.aarch64.conf .config            # ROCKNIX SM6115 defconfig
scripts/config --file .config \
  -e NETFILTER -e IP_MULTIPLE_TABLES -e IPV6_MULTIPLE_TABLES -e TUN \
  -e NF_TABLES -e NF_TABLES_INET -e IP_NF_IPTABLES -e IP_NF_NAT -e NF_NAT \
  -m NFT_NAT -m NFT_MASQ -m NFT_COMPAT -m NFT_REJECT -m NETFILTER_XT_TARGET_MASQUERADE \
  -e IKCONFIG -e IKCONFIG_PROC
scripts/config --file .config --set-str INITRAMFS_SOURCE "" -d LOCALVERSION_AUTO
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION=-nf Image.gz modules
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION=-nf \
     INSTALL_MOD_PATH=stage INSTALL_MOD_STRIP=1 modules_install
```

`INITRAMFS_SOURCE` must be cleared: the ROCKNIX defconfig points it at their
build host, and the initrd loaded by the bootloader is external.

**The initrd contains no modules.** Every symbol needed to reach the rootfs
(MMC/SDHCI, EXT4, VFAT/NLS, pinctrl/regulator/clock/interconnect, DRM_MSM)
therefore has to stay `=y`. Before installing, diff the new `.config` against
the running `/proc/config.gz` and refuse to continue if any `=y` symbol became
`=m` or unset.

## Installing

Modules first, as their own tree, then swap the kernel image and keep the
previous one:

```sh
tar -C / -xzf modules-<ver>.tgz          # /lib/modules/<ver>
depmod -a <ver>
cp -p /mnt/boot/KERNEL /mnt/boot/KERNEL.<old>
cp KERNEL.new /mnt/boot/KERNEL
sync
```

The DTB is **not** rebuilt and does not change: it lives on the FAT partition and
is loaded by `FDT` from `extlinux.conf`. The kernel must still match its
compatibles (`retroidpocket,duolite-hx83112a`, `retroidpocket,wl818s`,
`qcom,sm6125-dp`, `qcom,sm6125-dpu`).

Rollback: boot the microSD rescue system, mount the internal FAT **by device
path** (both partitions are labelled `ROCKNIX`), copy the saved image back.

## Test checklist after boot

- `uname -r` matches the new kernel and `systemctl --failed` is empty
- both panels connected (`/sys/class/drm/card0-DSI-1/status`, `card0-DP-1`)
- 3 × DPMS off/on, screen returns each time
- lid close sleeps and lid open resumes (`/sys/power/suspend_stats/success`)
- charger attach/detach with no errors in `dmesg | grep -iE 'bq256|jeita'`
- `nft list ruleset`, `iptables -L`, `ip rule` all work
- audio card present, remoteprocs `running`

## Upstream status

Realistically upstreamable, in rough order of effort:
sm6125 clk/pinctrl/interconnect/MPM fixes, the board DTS with bindings, the
sm6125 DP controller, the hx83112a panel variant, parts of the bq256xx work.

Not upstreamable in this form: the DPU rotator / qseed / smart-DMA / VBIF work
(downstream design), the PSCI suspend fallback, the WCN3990/3950 workarounds,
and the rsinput gamepad as written.

## Authorship and licensing

- The patches are kernel code: **GPLv2**, like the kernel. The original
  `From:`/`Date:`/`Signed-off-by:` headers are preserved where the source patch
  had them (41 of 79).
- The other **38 carry no author line in the source patch**; their commits are
  attributed to the port identity. That means authorship is *unknown*, not
  transferred. Do not submit those upstream without establishing who wrote them.
- The rebase, the 0032 resolution and the tooling in `toolkit/kernel/` are this
  project's work, MIT.
