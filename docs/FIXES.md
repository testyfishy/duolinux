# Upstream and community fix sweep

Checked 2026-10-30, after pivoting to the Duo Lite.

## ROCKNIX is the Duo Lite upstream

`ROCKNIX/distribution`, branch `next`, has a complete `projects/ROCKNIX/devices/SM6115` port that
includes the Duo Lite. This is the hardware enablement this distro builds on.

Relevant pieces:

- `linux/dts/qcom/sm6125-retroid-pocket-duo-lite.dts` — the device tree
- `patches/linux/0011-input-touchscreen-add-himax-hx83112a-spi-driver.patch`
- `patches/linux/0060-gpu-drm-panel-hx83112a-add-retroid-pocket-duo-lite.patch`
- `patches/linux/0071-drm-panel-add-retroid-pocket-duo-lite-bottom-panel.patch`
- `patches/linux/0072-drm-bridge-add-wl818s-dp-to-mipi-bridge.patch`
- `patches/linux/0070-backlight-add-wl818s-bridge-mcu-backlight.patch`
- `patches/linux/0023`–`0026` — WCN3950 Bluetooth
- `patches/linux/0078`–`0079` — WCN3990 ath10k workarounds
- `patches/linux/0004` — A610 GPU overclock (not used by default)
- charger/battery/fan/DP patches (0006–0032, 0061–0077)

Nightly used: `ROCKNIX-SM6115.aarch64-20261029`:

- `KERNEL` 34,765,312 bytes, raw arm64 Image, kernel **7.2.0**
- `SYSTEM` squashfs with 274 modules under `kernel-overlays/base/lib/modules/7.2.0`
- Duo Lite DTB 92,087 bytes
- `abl_signed-SM6115.elf` 532,480 bytes
- WCN3990 board data for `retroid-duolite`, WCN3950 firmware, ADSP/A610/Venus firmware, UCM

## ABL

`ROCKNIX/abl` latest tag is **v1.2**; assets include `abl_signed-SM6115.elf`. This is the image the
Lite needs. Unlike the flagship Duo, there is no missing-ABL blocker here.

## Retroid's official Linux tree

`RetroidPocket/linux` branch `retroidpocket/v7.3` supports the **flagship Duo** (`eliza`, Q-7790),
RP6 and Nova. It does **not** support the Lite. Do not build that tree for this device. The repo
keeps an `rpduo` profile for completeness, but it is not the target.

## Community trees

`RPQ7790Dev/*` is the flagship Duo Android/LineageOS port (CQ7790S). It is not the Lite and is not
used here.

For the Lite, the authoritative source is ROCKNIX's SM6115 tree and nightly.

## Open questions

1. Does the ROCKNIX ABL/BLS loader honor an external `initrd` line? If not, the embedded ROCKNIX
   initramfs runs and looks for their SYSTEM squashfs. `fastboot boot` avoids this; a source-built
   kernel with our initramfs linked in is the permanent fix.
2. Touch device names on a Debian/udev system (`hx83112a`, `fts_ts` or vendor names). `duo-layout`
   maps by name and can be overridden.
3. Whether the qrb4210 sound card needs an extra topology file beyond UCM.

## Re-run the sweep

```sh
# ROCKNIX device files
curl -s https://api.github.com/repos/ROCKNIX/distribution/contents/projects/ROCKNIX/devices/SM6115?ref=next | jq -r '.[].name'

# latest nightly
curl -s https://api.github.com/repos/ROCKNIX/distribution-nightly/releases/latest | jq -r '.tag_name, (.assets[].name)'

# ABL
curl -s https://api.github.com/repos/ROCKNIX/abl/releases/latest | jq -r '.tag_name, (.assets[].name)'
```
