# Microphone

**Status: not working. The mic is powered, its pins are muxed, and both LPASS
macros' DMIC clocks can be enabled by hand; the data line still returns only
slow DC wander, never audio.** Everything below is measured on the device.

## What works

- The microphone is **powered**: after routing `"TX DMIC2", "MIC BIAS1"` in the
  device tree the capture changed from exact digital zeros to real signal, so
  the WCD9370's MIC BIAS1 is switching on.
- The pads are muxed correctly: `gpio127` = `dmic1_clk`, `gpio128` =
  `dmic1_data` (pair 1 = TX DMIC2/DMIC3), confirmed in
  `/sys/kernel/debug/pinctrl/500000.pinctrl/pinmux-pins` during capture.
- The capture path itself is healthy: `hw:0,2` opens, the decimator runs
  (TX macro `0x0400` goes `0x04` → `0x24` while streaming), gain is 84, and
  transcription works on any clip that contains speech.

## What is wrong

The data line carries no PDM data. Measured via `/dev/mem` MMIO:

| Register | Idle | During capture | Meaning |
|---|---|---|---|
| TX `0x0400` (DEC0 path) | `0x04` | `0x24` | decimator genuinely running |
| TX `0x00C0/0x00C4` (DMIC clock) | `0x0E` | `0x0E` | never programmed by mainline |
| TX `0x00C4` bit 0 | — | never sets, even written as `1` | **read-only status, not an enable** |
| VA `0x0000` (MCLK) | `0x1` | `0x1` | VA macro clocked |
| VA `0x0084/0x0088` (DMIC clock) | `0x00` → written `0x09` | stays `0x09` | clock enabled by hand, no effect |

With the VA DMIC clocks *and* both macros' MCLK running, a 1 kHz tone at full
speaker level still yields `rms ~3000` with **2 zero crossings per second** —
i.e. a slow DC wander, not audio. Real speech is hundreds to thousands.

## What Android does (from the vendor's own binaries)

The Android partitions are intact on the eMMC and were used as the reference:

- `vendor_dlkm` (a logical partition inside `super`) mounts read-only at
  offset `0x128300000` and contains the vendor modules with **full symbols**.
- `bolero_cdc_dlkm.ko` has `bolero_dmic_clk_enable`. Its `.rodata` tables map
  DMIC index → register and enable bit:

  | Table | Values |
  |---|---|
  | register | `0x3084, 0x3088, 0x308c, 0x3090` |
  | enable bit | `1, 2, 4, 8` |

  i.e. the **VA macro's** `DMIC0..3_CTL` block, not the TX macro's.
- The vendor tx-macro node carries `qcom,tx-dmic-sample-rate = <0x249f00>`
  (2.4 MHz), so the intended PDM clock is MCLK/4 from the 9.6 MHz MCLK.
- The vendor's own `mixer_paths.xml` selects the mic with `TX DMIC MUX0=DMIC2`
  (path `handset-dmic-endfire`), matching our mux.

## Dead ends (do not repeat)

- Writing the TX macro divider: the field takes (`0x08`) but bit 0 never
  latches and the register is reset to `0x0E` at stream start.
- Poking the VA macro DMIC registers and MCLK: values stick, audio does not
  appear.
- Sweeping `TX DMIC MUX0` across DMIC0..7 with the clock programmed: all zero
  except the unmuxed pair-0 pad, which floats.
- The TX macro DMIC clock is *not* an enable bit; the driver's own comment says
  the default value `0` means DIV2 (4.8 MHz), which is above a PDM mic's limit.

## Next step

Get the vendor audio-kernel source (its debug strings name
`vendor/qcom/opensource/audio-kernel/legacy/asoc/...`), read
`bolero_dmic_clk_enable` and its callers, and find the register or clock-gate
sequence that actually makes the pad produce a clock. Qualcomm's audio-kernel is
public, so this needs no hardware access.

## Tooling this produced

| Tool | Purpose |
|---|---|
| `toolkit/apps/pmem.py` | read/write 32-bit MMIO through `/dev/mem` (no rebuilds) |
| `toolkit/apps/parse-super.py` | parse super's LP metadata, print partition extents |
| `toolkit/apps/find-super-fs.py` | locate a filesystem by magic inside the raw partition |
| `toolkit/apps/disasm-vendor-dmic.sh`, `dump-vendor-dmic-tables.sh` | vendor `bolero` analysis |
| `toolkit/apps/dmic-*.sh`, `va-*.sh` | the sweeps and probes above |

## Volume control on this card (affects every test script)

`amixer` cannot touch this card: `cget`/`cset` abort with
`control.c:427: snd_ctl_elem_info` (rc 134) for every numid except 1, while
`alsactl` works because it uses `ELEM_READ`. All tooling drives controls through
a stored state file (`alsactl store` / edit / `restore`).

## Other details

- `arecord` on `hw:0,2` gets truncated while PipeWire holds the card; use
  `pw-record` as `duo` with `XDG_RUNTIME_DIR=/run/user/1000`, stopped with
  SIGINT (`timeout -s INT`) so the WAV header is finalised.
- Only `hw:0,2` is routed for capture; `hw:0,0` and `hw:0,1` fail with `EINVAL`.
