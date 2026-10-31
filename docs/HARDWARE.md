# Hardware — Duo Lite

The Lite is **not** the flagship Duo. It is a Qualcomm **QCS6125 / SM6125** device (Snapdragon
662-class, "bengal" family), and the Linux board support comes from ROCKNIX's SM6115 device port.

| | |
|---|---|
| SoC | Qualcomm QCS6125 / SM6125, 4×Cortex-A73 + 4×Cortex-A53 |
| GPU | Adreno 610 (A610 zap shader `qcom/sm6125/a610_zap.mbn`) |
| RAM | 4 GB or 6 GB LPDDR4X |
| Storage | 64 GB or 128 GB eMMC + microSD |
| Top panel | 5.5" 1920×1080 LCD 60 Hz, Himax HX83112A, portrait-native, `rotation = <270>` |
| Bottom panel | 4.2" 1280×960 LCD 60 Hz, behind the WL818S MIPI bridge |
| Touch (top) | Himax HX83112A over SPI, 1080×1920 |
| Touch (bottom) | Focaltech FT5452 over I2C, 1280×960 |
| Wi-Fi | WCN3990 (ath10k), board data `ath10k/WCN3990/hw1.0/retroid-duolite/` |
| Bluetooth | WCN3950 (`qcom,wcn3950-bt`, firmware `retroid-duolite/cmnv13.bin`) |
| Audio | QRB4210 sound card, LPASS RX/TX/VA macros, AW882xx speaker amps, ES8326 codec |
| Power | 6000 mAh, PMI632 + charger, battery OCV table in the DTS |
| Cooling | PWM fan with thermal trips from 45 °C |
| Input | RSInput UART gamepad, volume key, hall lid sensor |
| USB | USB-C 3.1 with DisplayPort alt mode (SM6125 DP controller) |

## Device tree facts

From ROCKNIX `projects/ROCKNIX/devices/SM6115/linux/dts/qcom/sm6125-retroid-pocket-duo-lite.dts`:

```dts
model = "Retroid Pocket Duo Lite";
compatible = "retroidpocket,duolite", "qcom,sm6125";
```

- `panel` compatible `retroidpocket,duolite-hx83112a`, `rotation = <270>`
- `panel-bottom` compatible `retroidpocket,duolite-bottom-panel`, with `panel_backlight`
  compatible `retroidpocket,wl818s`
- `touchscreen@48` compatible `himax,hx83112a`, 1080×1920
- `touchscreen@38` compatible `focaltech,ft5452`, 1280×960
- `wifi@c800000` compatible `qcom,wcn3990-wifi`, `firmware-name = "retroid-duolite"`
- `bluetooth` compatible `qcom,wcn3950-bt`, `firmware-name = "retroid-duolite/cmnv13.bin"`
- `sound` compatible `qcom,qrb4210-rb2-sndcard`, model `RetroidPocketDuoLite`
- `remoteproc_adsp` firmware `qcom/sm6125/adsp.mbn`
- `gpu_zap_shader` firmware `qcom/sm6125/a610_zap.mbn`
- `fan` PWM + tach on GPIO 0, cooling levels 0…191

## Firmware layout

The nightly's `SYSTEM` squashfs contains a kernel-overlay firmware tree. `duo fetch` extracts it and
the Debian rootfs installs it under `/usr/lib/firmware`:

```
ath10k/WCN3990/hw1.0/retroid-duolite/{board-2.bin,firmware-5.bin}
qca/cmbtfw13.tlv, cmnv13.bin...
qcom/sm6125/adsp.mbn, adspr.jsn, adsps.jsn, adspua.jsn
qcom/sm6125/modem.mbn
qcom/sm6125/aw883xx_acf.bin
qcom/sm6125/a610_zap.mbn
qcom/a630_sqe.fw
qcom/venus-6.0/venus.mbn
Himax_firmware.bin
```

The exact `retroid-duolite` board directory is why generic `firmware-atheros` alone is not enough;
the build copies the nightly's files and also installs Debian's `firmware-atheros` as a fallback.

## Display notes

Both panels are on the MSM DRM card. Expect `DSI-1` (top) and `DSI-2` (bottom). The top panel's
native mode is portrait 1080×1920; `duo-layout` sets `transform 270` to get 1920×1080 landscape.
The bottom panel is 1280×960 landscape.

If the top image is upside down, change `transform 270` to `90` in
`overlay/usr/local/bin/duo-layout`. If touch is rotated relative to the image, add a `calibration`
matrix in `/etc/sway/config`.

## Sources

- ROCKNIX device port: <https://github.com/ROCKNIX/distribution/tree/next/projects/ROCKNIX/devices/SM6115>
- Nightly used: `ROCKNIX-SM6115.aarch64-20261029` (kernel 7.2.0)
- ABL: `ROCKNIX/abl` release v1.2 (`abl_signed-SM6115.elf`)
- Kernel patches: `projects/ROCKNIX/devices/SM6115/patches/linux/*.patch`
