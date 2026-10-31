# Gaming: getting the Steam library onto the device

## The conclusion first

The Steam client **cannot run on this device**, and that is a hardware limit, not
a packaging one:

- The cores are Kryo 260 (Cortex-A73/A53), **ARMv8.0**, no LSE atomics
  (`grep -c atomics /proc/cpuinfo` returns 0 of 8).
- Valve's native arm64 Steam client requires ARMv8.1 LSE.
- Canonical's arm64 Steam snap runs the x86 client through FEX, which on
  ARMv8.0 is either slow or needs memory-ordering emulation disabled.

Local x86 translation also does not fit the actual goal. Hangover (Wine + box64/
FEX) exists and has a Debian 13 arm64 build, but it runs individual Windows
binaries; the games live in a Steam library behind Steam's client and DRM.

**So the library stays on the PC and is streamed.** That keeps saves, workshop
content and anti-cheat working, and turns the handheld into a screen and a pad.

## Route: Moonlight + Sunshine

| Side | Software | State |
|---|---|---|
| Device | `com.moonlight_stream.Moonlight` 6.2.0, Flathub aarch64 | **installed** |
| HTPC | Sunshine, `LizardByte.Sunshine` (winget) | to install |

Setup: Sunshine on the Windows HTPC, paired to Moonlight on the device, then
launch Steam Big Picture as a Sunshine app entry.

Expected: ~10-20 ms added latency on 5 GHz Wi-Fi, full PC quality, decode in
**software** on the device's four big cores (see below).

## Venus (hardware video codec): investigated, deliberately not enabled

The hardware and the driver are both present; what is missing is the SoC clock
description.

| Piece | State |
|---|---|
| Venus hardware (SM6125, full AR50 - sc7180 family) | present |
| `venus-core/dec/enc.ko` | built and **loading** |
| Firmware `qcom/venus-5.4/venus.mbn` | present |
| DT node | only in `sm6115.dtsi`, disabled; this board uses `sm6125.dtsi` |
| `gcc-sm6125.c` Venus clocks and GDSCs | **absent** - no venus_clk_src, venus_ctl, vcodec0 clocks, no VENUS/VCODEC0 GDSCs |
| ROCKNIX | never enabled Venus on this board either |

Enabling it means writing a patch: a `venus_resources` entry for sm6125
(modelled on sc7180, **not** sm6115 - bengal is AR50_LITE and has a different
clock set), the clock and GDSC definitions, dt-binding IDs, and a DT node with
the right IOMMU stream IDs.

Sources to take it from, if it is ever done:

- downstream `gcc-trinket.c` / `gcc-trinket.h`, trinket GDSC addresses in
  `trinket-gdsc.dtsi` (LineageOS `android_kernel_xiaomi_sm6125`, CLO LA.UM.8.x)
- the stock Android DTB for `iommus`, the reserved memory region and clock names
  (`dtc -I fs /proc/device-tree`)
- the sm6125-mainline group's tree, before writing anything

Risks: a wrong GDSC/clock offset can gate an unrelated clock and hang the board
at `clk_disable_unused`; a wrong SMMU stream ID typically reboots the device;
firmware must be vendor-signed if secure boot is fused.

**Verdict: skip.** For 720p60 H.264, software decode costs roughly 20-35 % of the
four big cores and 3-6 ms/frame. Revisit if streaming moves to 1080p120, HEVC or
4K, if battery life becomes critical, or if SM6125 Venus support lands upstream.

## Daily tools

| Tool | Package | State |
|---|---|---|
| Syncthing | Debian `syncthing` 1.29.5, `syncthing@duo.service` | **enabled and running** |
| Tailscale | pkgs.tailscale.com 1.104.4, TUN mode on the 7.2.11-nf kernel | running, **needs login** |
| Tailscale tray | upstream `tailscale systray` | installed and autostarting |

Syncthing GUI: `http://127.0.0.1:8384` on the device, or tunnel it from the PC:

```
ssh -i out/duo_ssh_key -N -L 8384:127.0.0.1:8384 root@<device>
```

## Acceptance tests

1. Moonlight pairs with Sunshine and streams 720p60 for 30 minutes: decode
   under 8 ms, no dropped frames in the stats overlay, pad works through
   InputPlumber.
2. A Syncthing folder syncs between the HTPC and the device, and survives a
   suspend/resume.
3. `tailscale ping <htpc>` reports a direct path, not DERP, and survives a
   reboot.
