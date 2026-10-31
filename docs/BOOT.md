# Boot chain and recovery — Duo Lite

The Lite is easier than the flagship: ROCKNIX has a signed **SM6115 ABL** and a known-good SD boot
layout. This document is about using them without losing the stock bootloader.

## What is known

- Boot chain: XBL → ABL → `KERNEL`.
- The ABL lives in `abl_a` / `abl_b`.
- ROCKNIX ABL v1.2 ships `abl_signed-SM6115.elf`. The nightly tar also contains it at
  `3rdparty/bootloader/openabl/abl_signed-SM6115.elf`, with `backup_abl.sh` / `flash_abl.sh`.
- ROCKNIX's BLS entry is:

```
title      ROCKNIX
linux      /KERNEL
options    boot=LABEL=ROCKNIX disk=LABEL=STORAGE rootwait quiet video=efifb:off console=tty0 gpt
```

Our image uses the same labels and layout, so the ABL finds what it expects.

## Path A — one-shot `fastboot boot` (start here)

Nothing is written. This is the safest way to test the kernel, panels and initramfs.

```powershell
.\duo.ps1 boot
```

It runs `adb reboot bootloader` then `fastboot boot out\boot-duolinux-duol.img`. The boot image
contains the ROCKNIX `Image`, our `initrd.img` (with `/duo-init`), the Duo Lite DTB, and
`rdinit=/duo-init`.

| Result | Meaning | Next |
|---|---|---|
| Console / Sway appears | Kernel + initramfs + rootfs work | Path B for persistence |
| `FAILED (remote: 'unknown command')` | Stock ABL refuses `fastboot boot` | Path B |
| Black screen, device alive | Initramfs loaded but root not found | Check label `STORAGE`; try serial |
| Boots ROCKNIX UI instead | The ABL ignored our external initrd and used the embedded one | Use the source-built kernel (BUILD.md) or Path A with a boot.img that the ABL honors |
| Immediate reset | Bad DTB / image | Re-enter fastboot; nothing written |

## Path B — boot from microSD with the SM6115 ABL

The image layout:

```
GPT
├── p1  ROCKNIX   FAT32, 512 MiB
│     KERNEL                 ROCKNIX arm64 Image (7.2.0)
│     Image.gz               compressed copy
│     initrd.img             our busybox initramfs, /duo-init
│     boot.img               for fastboot
│     dtbs/qcom/sm6125-retroid-pocket-duo-lite.dtb
│     extlinux/extlinux.conf
│     loader/entries/duolinux.conf
└── p2  STORAGE   ext4, rest of card
      Debian 13 arm64
```

Install:

1. Write the image to the card (`duo install --disk N`, or `--via-adb`).
2. In Android: Settings → Handheld Settings → Advanced → Run script as root.
3. Run `install_sd.sh` (writes the card).
4. Run `flash_abl.sh` (backs up `abl_a`/`abl_b`, then flashes `abl_signed-SM6115.elf`).
5. Copy `abl_a.img` and `abl_b.img` off the device.
6. Power off. Hold **Volume Down** at power-on.
7. Set **Boot mode = Linux**, **Boot source = SD Card**, then **Start**.

## The initramfs question

The ROCKNIX `KERNEL` is a monolithic Image with an embedded initramfs that boots their squashfs
system. We do not want that. We load our own `initrd.img` and pass `rdinit=/duo-init`, which tells
the kernel to run our init instead of the embedded `/init`.

This relies on the bootloader honoring the `initrd` line (BLS) or the boot image ramdisk (fastboot).
If it does not, the kernel will run ROCKNIX's init, look for their SYSTEM squashfs, and fail. The
fallback is a source-built kernel with our initramfs linked in; the patchset and config are
documented in BUILD.md.

## Recovery

Before flashing the ABL, `flash_abl.sh` runs:

```sh
dd if=/dev/block/by-name/abl_a of=/sdcard/Download/duolinux/abl_a.img bs=1M
dd if=/dev/block/by-name/abl_b of=/sdcard/Download/duolinux/abl_b.img bs=1M
```

Copy both files off the device. To restore, from a root script:

```sh
dd if=/sdcard/Download/duolinux/abl_a.img of=/dev/block/by-name/abl_a bs=1M
dd if=/sdcard/Download/duolinux/abl_b.img of=/dev/block/by-name/abl_b bs=1M
```

If Android still boots, the ABL menu (Volume Down at power-on) can select Android. If the device
will not boot at all, Qualcomm EDL is the last resort; it needs the vendor firehose programmer, which
this repository does not ship. Do not start EDL experiments casually.

## Why these labels

`ROCKNIX` and `STORAGE` are not branding; they are the labels the ROCKNIX ABL and BLS entry expect.
Renaming them is possible but removes the compatibility that makes this image bootable.
