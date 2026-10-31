# Microphone: what the hardware actually does

**Status: no working built-in microphone on mainline 7.2.11-nf.** Capture itself
works end to end (PCM opens, gain control, PipeWire source, HTTP transcription),
but neither the digital mic path nor the analog codec path delivers audio. This
page records the evidence so it does not have to be rediscovered.

## The capture path

`hw:0,2` (frontend `MultiMedia3`) -> `TX_CODEC_DMA_TX_3` -> `tx_macro`
(`a460000.codec`) -> DEC0 -> either `MSM_DMIC` (digital mics) or `SWR_MIC`
(analog mic through the WCD9370). The UCM device is:

```
SectionDevice."Mic" {
    cset "name='TX DEC0 MUX' MSM_DMIC"
    cset "name='TX DMIC MUX0' DMIC2"
    cset "name='TX_AIF1_CAP Mixer DEC0' 1"
    cset "name='TX_DEC0 Volume' 84"
    CapturePCM "hw:0,2"   # 1 ch, 48 kHz
}
```

Only `hw:0,2` is routed for capture. `hw:0,0` and `hw:0,1` open then fail with
`EINVAL` because no capture backend is attached to those frontends.

## Digital mic pads

`500000.pinctrl` exposes four DMIC functions, one clock/data pair each:

| Function | Pin | Pair | TX-macro inputs |
|---|---|---|---|
| `dmic0_clk` / `dmic0_data` | gpio125 / gpio126 | 0 | DMIC0, DMIC1 |
| `dmic1_clk` / `dmic1_data` | gpio127 / gpio128 | 1 | DMIC2, DMIC3 |

The board DTS pin group is named `dmic23_active` but contains `dmic1_clk` /
`dmic1_data`, i.e. **pair 1**, which the TX macro numbers DMIC2/DMIC3. The group
name refers to the SoC's DMIC2/3 inputs, not to pin index. Pair 0 is unclaimed
in `pinmux-pins`, so selecting DMIC0/DMIC1 reads a floating pad.

Sweep with `TX DMIC MUX0 = 0..7`, 2-3 s each through `pw-record`:

| Input | Result |
|---|---|
| DMIC0 | exact digital zero |
| DMIC1 | rms ~4600, peak 32768, ~5-20 zero crossings/s - floating pad |
| DMIC2 (UCM value) | exact digital zero |
| DMIC3 | exact digital zero |
| DMIC4..7 | exact digital zero |

Real speech is hundreds to thousands of zero crossings per second and a noise
floor around -50 dBFS. Exact zeros are the signature of a clocked decimator with
no PDM data; slow-wobble-with-spikes is a floating input.

## It is not a settings problem

Measured while a stream was running (`/sys/kernel/debug/regmap/a460000.codec-tx_macro/registers`):

| Register | Value | Meaning |
|---|---|---|
| `0x0000` | `00000001` | TX MCLK enabled |
| `0x0090` | `00000001` | 9.6 MHz MCLK selected |
| `0x00c0`-`0x00cc` | `0000000e` | DMIC0..3 clock fields set |
| `0x0100` | `00000020` | DEC0 input mux = DMIC2 |
| `0x0104` | `00000000` | SWR bit clear -> MSM_DMIC mode |
| `0x0400` | `00000024` | DEC0 path control, clock enabled |

So the macro is clocked, the decimator is pointed at the right input, the pads
are muxed, and nothing arrives. The analyzer also rules out a word-width bug:
a 32-bit capture is MSB-aligned (`values are multiples of 65536: 190464/190464`,
low halfword always zero), so the S16 view is correct.

## Analog path

The DTS wires the WCD9370 as `AMIC2 <- MIC BIAS2` and `TX SWR_INPUT1 <- ADC2_OUTPUT`,
the usual headset-mic route. Driving it from userspace:

```
cset "name='TX DEC0 MUX' SWR_MIC"
cset "name='TX SMIC MUX0' SWR_MIC1"
cset "name='ADC2 MUX' INP2"
cset "name='ADC2_MIXER Switch' 1"
cset "name='ADC2 Switch' 1"
cset "name='ADC2 Volume' 20"
cset "name='TX_AIF1_CAP Mixer DEC0' 1"
cset "name='MultiMedia3 Mixer TX_CODEC_DMA_TX_3' 1"
```

Result: 7.96 s capture, rms 2766, peak 32768, **2 zero crossings per second** -
a floating analog input, not a microphone. `dmesg` also notes
`wcd937x_codec audio-codec: supply vdd-mic-bias not found, using dummy regulator`,
so whether the board even powers mic bias is unknown.

## Gotchas that cost time

- `amixer sget`/`cget` **by name can abort**; `cset` works. The driver's get
  callback reports stale values (`TX_DEC0 Volume` reads back 1 after being set
  to 84). Trust the write, verify by measuring the capture, not by reading back.
- `arecord -D hw:0,2` gets **truncated** while PipeWire holds the card: a 45 s
  request produced 8 s of audio. Use `pw-record` as the desktop user, or stop
  PipeWire first.
- `pw-record` must run as `duo` with `XDG_RUNTIME_DIR=/run/user/1000`; as root
  it cannot reach the session PipeWire.
- The hardware actually negotiates `S24_LE` at 48 kHz even when asked for s16;
  that is normal and harmless.
- Capture gain is `TX_DEC0 Volume` (0-124), not `ADC1 Volume`. The UCM wants 84;
  it is usually 1 (about -83 dB) because the EnableSequence is not applied when
  a plain PCM client opens the device.

## What would settle it

1. The vendor Android `mixer_paths*.xml` / `audio_platform_info.xml`, which
   names the real mic (DMIC index or AMIC input) and any bias regulator.
2. A TRRS headset in the 3.5 mm jack with the analog route above: if that
   produces speech, the codec/SWR/DSP chain is fine and only the internal mic
   is missing or unpowered.
3. The schematic, for mic VDD and the DMIC data line.
