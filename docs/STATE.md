# State of the port

One page, current as of the last commit. Everything here was measured on a
Pocket Duo Lite, not inferred. Deep detail is linked per row.

## Subsystems

| Subsystem | Status | Why / what blocks it | Detail |
|---|---|---|---|
| Both panels, touch, 2-screen layout | **works** | - | `docs/HARDWARE.md` |
| Plasma 6 desktop, KWin rules, taskbars | **works** | - | `docs/PLASMA.md` |
| Gamepad input, stick-to-mouse, mapping | **works** | - | `docs/DAILY.md` |
| On-screen keyboard (wvkbd fork) | **works** | - | `docs/PLASMA.md` |
| Wi-Fi (2.4 GHz pinned), Bluetooth | **works** | 5 GHz links at unusable rates on this board | `docs/WIRELESS.md` |
| Lid suspend / resume | **works** | - | `docs/SUSPEND.md` |
| Fan curve | **works** | - | `docs/PERFORMANCE.md` |
| Chargers, battery reporting | **works** | - | `docs/HARDWARE.md` |
| Tailscale (TUN mode, survives suspend) | **works** | needs netfilter in the kernel | `docs/WIRELESS.md` |
| Streaming (Moonlight/Sunshine) | **works** | software decode only | `docs/GAMING.md` |
| Jellyfin playback | **works** | cap the stream to 6-10 Mbit/s | `docs/GAMING.md` |
| Audio playback | **works, quiet** | amps at their profile maximum; Android's extra gain is ADSP ACDB/COPP, which mainline cannot load | `docs/SPEAKERS-NEXT.md` |
| Volume slider | **dead** | the card's `ELEM_INFO` is broken, so PipeWire cannot drive the amp; `alsactl` still works | `docs/SPEAKERS-NEXT.md` |
| Microphone | **not working** | no PDM clock; the vendor enables it through a clock-resource layer mainline lacks, and audioreach needs SPF firmware bengal does not ship | `docs/MICROPHONE.md` |
| Hardware video (Venus) | **partial** | driver, `videocc`, DTS and DTB in place; decoder/encoder nodes register, but the core never powers (`venus_gdsc off`, reset timeout) | `docs/HELP-WANTED.md` |
| Amp stop-check message | **cosmetic** | `pa stop check fail:0x0330` on every stop; playback works | `docs/HARDWARE.md` |

## Out of scope

Stated so the open rows read as known limits rather than unfinished work:

- **Anything requiring vendor DSP firmware or calibration.** This covers the
  microphone clock, ADSP/ACDB/COPP audio processing and the speaker loudness.
  The firmware is signed and cannot be replaced.
- **Hardware video decode/encode** until the SM6125 `videocc` table is known.
- **Other devices.** This port targets the Duo Lite (SM6125) only.
- **OTA updates, package repositories, CI.** One image, one device.
- **Support.** It is a hobby port; see `docs/HELP-WANTED.md` if you want to pick
  something up.

## Rebuilding from scratch

1. Windows 11 + WSL2 (Ubuntu 26.04), or any Linux with the package list in
   `docs/BUILD.md`.
2. `duo setup --native` - cross toolchain and image tools.
3. `duo fetch` - pins the ROCKNIX nightly and Tailscale release from `duo.json`,
   so the base is reproducible; the file records the version and URL.
4. `duo kernel` - copies the ROCKNIX kernel/DTB/modules into `out/kernel/`.
5. `duo rootfs` - `mmdebstrap` Debian 13 arm64 rootfs with
   `configs/rootfs/packages.list`.
6. `duo image` - initramfs, `boot.img`, GPT image:
   `out/duolinux-duol.img`.

Kernel from source instead of the prebuilt base:
`toolkit/kernel/build-nf-7.2.11.sh` (see `docs/KERNEL.md`); the patch series is
in `kernel/patches/7.2.11/`.

Cross-compiled components (wvkbd, whisper.cpp) build on the PC:
`toolkit/cross/` - see `docs/BUILD.md`.

## If you pick this up

The two highest-value items are the microphone clock and the SM6125 `videocc`
table. Both need configuration values that only the vendor (or someone with
working vendor Android) can supply; `docs/OUTREACH.md` records the request and
the channel that works.
