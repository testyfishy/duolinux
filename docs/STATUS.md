# Status

Last updated: 2026-10-30. This is an honest ledger, not marketing.

## Target correction

The first pass of this project targeted the **flagship Retroid Pocket Duo** (Q-7790 / Eliza), because
that was the device named in the brief. The actual device is the **Duo Lite** (QCS6125 / SM6125).
The two are different platforms: different SoC, different panels, different touch controllers,
different Wi-Fi, different bootloader.

The project now targets the Lite. The Eliza code path remains selectable with
`"device": "rpduo"` in `duo.json`, but it is not what you should build.

## Verified here

| Thing | Evidence |
|---|---|
| The Duo Lite is SM6115/SM6125 | ROCKNIX DTS `compatible = "retroidpocket,duolite", "qcom,sm6125"` |
| Both panels are supported | `retroidpocket,duolite-hx83112a` (top, `rotation = <270>`) and `retroidpocket,duolite-bottom-panel` behind the WL818S bridge |
| Touch is supported | Himax HX83112A (top, SPI, 1080×1920) and Focaltech FT5452 (bottom, I2C, 1280×960) |
| Wi-Fi/BT are supported | WCN3990 (`qcom,wcn3990-wifi`, firmware `retroid-duolite`) and WCN3950 (`qcom,wcn3950-bt`) |
| ROCKNIX ships a signed SM6115 ABL | `3rdparty/bootloader/openabl/abl_signed-SM6115.elf`, plus backup/flash scripts |
| A matching kernel exists | ROCKNIX SM6115 nightly 20261029: `KERNEL` (raw arm64 Image), DTB, 274 modules for 7.2.0 |
| The module/firmware/UCM set is complete | extracted from `SYSTEM`: 274 `.ko`, WCN3990 `retroid-duolite` board files, ADSP, A610 zap, UCM |
| Our initramfs is built and packs | busybox arm64, `/duo-init`, 993 KiB gzip cpio |
| Our `boot.img` packs | Android header v2, 34 MiB kernel + initrd + DTB, `tests/test_bootimg.py` passes |
| Our SD image assembles | GPT with `ROCKNIX` (FAT32) + `STORAGE` (ext4); FAT contains `KERNEL`, `Image.gz`, `boot.img`, `initrd.img`, `dtbs/`, `extlinux/`, `loader/`; ext4 label verified |
| The cockpit renders | `duo demo`, pure-stdlib curses layout |
| A real Debian rootfs builds | `mmdebstrap` + qemu-user, 538 packages, Sway/Foot/Tailscale/NetworkManager, ~30 min on this host |
| The final SD image is real | `out/duolinux-duol.img` 8,059,372,544 bytes, ext4 label `STORAGE` 7.0 GiB, GPT `ROCKNIX` + `STORAGE`; checksum in `out/SHA256SUMS` |
| Boot files are in the FAT partition | `KERNEL` 34.7 MiB, `boot.img` 35.8 MiB, `initrd.img` 1.0 MiB, Duo Lite DTB, BLS entry |
| First-boot diagnostics | `/duo-init` appends a timestamped `/duo-boot.log` to the FAT `ROCKNIX` partition before attempting `switch_root` |

## Not yet verified (needs the device)

1. **External initramfs loading.** The ROCKNIX `KERNEL` has an embedded initramfs that boots their
   squashfs system. We pass `rdinit=/duo-init` and load our own `initrd.img` through BLS/extlinux.
   If the ABL ignores `initrd`, the kernel will run ROCKNIX's init instead. The fallback is
   `fastboot boot boot.img`, which passes the initrd explicitly, or a source-built kernel with our
   initramfs linked in.
2. **Panel orientation.** The top panel is portrait-native (`rotation = <270>`); `duo-layout` applies
   transform 270 when it sees a portrait mode. One `swaymsg -t get_outputs` confirms it.
3. **Touch-to-output mapping.** Device names may be `hx83112a`/`fts_ts`; `duo-layout` maps by name
   containing `bottom`/`secondary`, with manual overrides in `/etc/sway/config`.
4. **Gamepad mapping.** The DTS uses the RSInput UART gamepad; the ROCKNIX kernel may name the
   device differently. `duo-inputd` logs the device it grabs.
5. **Wi-Fi regulatory/board data.** The correct `ath10k/WCN3990/hw1.0/retroid-duolite/` files are in
   the nightly and are copied into the rootfs. `dmesg | grep ath10k` will confirm.
6. **Audio.** The UCM tree from the nightly is copied. The qrb4210 sound card may need an additional
   topology file; start with `aplay -l` and `speaker-test`.
7. **Suspend, fan curve, battery gauge.** Drivers are present; behaviour on hardware is unmeasured.

## Known blockers

- **`fastboot boot` may be refused** by a locked stock ABL. The ABL replacement is the persistent
  path; the SM6115 image is available and includes a stock-ABL backup.
- **Rootfs build needs root** for `chroot`/`mmdebstrap`. It was built here with
  `mmdebstrap` + qemu-user in ~30 minutes. `duo setup --native` is the fast path;
  `duo setup --rootless` avoids sudo for the toolchain. Image assembly runs `mke2fs` under
  `sudo` so setuid bits and ownership survive.
- **The 1.4 GB hardware base is a nightly.** Pin `rocknix_version` in `duo.json` if you need
  reproducibility. ROCKNIX is GPL-2.0; the source build path is documented.

## What "done" looks like

1. `duo probe` shows the Lite (`ro.product.device=RPDuo`, `ro.board.platform` SM6115/SM6125).
2. `duo boot` reaches a console on the top panel.
3. `swaymsg -t get_outputs` lists both panels with the expected modes.
4. `tailscale status` shows the device on the tailnet.
5. The cockpit shows latency to the server and `nvidia-smi`/`ollama` output.
