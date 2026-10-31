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
| Audio | QRB4210 sound card, LPASS RX/TX/VA macros, WCD9370 codec over SoundWire, 2× AW88166 amps |
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

## Speakers: AW88166 volume control

Two Awinic **AW88166** class-D amplifiers sit at i2c 0x34 (SPK_R) and 0x35 (SPK_L), driven by
`sound/soc/codecs/aw88166.c`, fed from `MM1 -> PRI_MI2S_RX`. The board firmware is
`qcom/sm6125/aw883xx_acf.bin`.

### The register

Register `05` (`SYSCTRL2`) bits `[9:0]` are an **attenuation counter** in 0.125 dB steps:
`0` is the loudest the chip can go, `1023` is silence. The ACF profile supplies this board's own
default; measured on the live device it is **12**, i.e. -1.5 dB.

### Why 100 % was effectively silent

The vendor driver computes

```c
real_value = min(control + init_volume, 1023);
```

so the ALSA control *adds attenuation*: `0` is the profile default (loud) and `1023` is mute.
Every consumer of an ALSA playback control assumes the opposite, and PipeWire maps 100 % onto the
control maximum — so "100 %" wrote 1023 and **muted** the amplifier. The measured register read
`0x83FF`, i.e. field 1023, exactly the mute value.

This is a polarity bug, not a level bug.

### Fix

`toolkit/kernel/fix-aw88166-volume-v3.sh` inverts the control across the whole hardware range and
makes the loudest reachable setting the profile's own default, so 0 dB stays unreachable:

| Control | Attenuation | Level |
|---|---|---|
| 0 | 1023 | silence |
| 256 | 770 | |
| 512 | 517 | about half way |
| 767 | 265 | |
| 1023 | 11 | the vendor's design point (-1.4 dB) |

All five rows are measured on the device, not predicted, by driving the control
through `alsactl` and reading register 05 from both amps. The ACF blob agrees:
all three of its register sections set register 05 to `0x800B`.

Mute, fade-in and fade-out keep their upstream attenuation semantics: the conversion happens only at
the ALSA control boundary. An earlier attempt (`fix-aw88166-volume-v2.sh`) put the mapping inside
`aw_dev_set_volume()`, which `fade_out()` calls with `MUTE_VOL` (1023) — that turned "mute" into the
loudest value. That kernel was installed for a short while and is superseded.

0 dB would be roughly 2 W into 8 Ω; the mapping never allows it.

### Notes

- The register is readable at `/sys/kernel/debug/regmap/0-003{4,5}/registers` and read-only there.
- `amixer sget`/`cget` **by name can abort**; `amixer -c0 controls` lists controls and
  `amixer -c0 cset numid=N` sets them.
- `pa stop check fail:0x0330` still appears on every playback start. Unresolved and separate from
  volume; bit 0 (PLL locked) is clear in that status word.
- PipeWire exposes the sink correctly as "Built-in Audio Speaker Playback".

## Microphone

There is no working built-in microphone: no DMIC input delivers data and the analog codec path reads
a floating input. The capture chain itself works. See `docs/MICROPHONE.md` for the full evidence.

## Sources

- ROCKNIX device port: <https://github.com/ROCKNIX/distribution/tree/next/projects/ROCKNIX/devices/SM6115>
- Nightly used: `ROCKNIX-SM6115.aarch64-20261029` (kernel 7.2.0)
- ABL: `ROCKNIX/abl` release v1.2 (`abl_signed-SM6115.elf`)
- Kernel patches: `projects/ROCKNIX/devices/SM6115/patches/linux/*.patch`
