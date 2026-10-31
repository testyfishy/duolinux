# Microphone

**Status: the microphone is powered but still not clocked.** The supply route in
the device tree works; the PDM clock does not exist yet.

## What is confirmed working

- The DMIC pair on gpio127/128 is **TX DMIC2/DMIC3** and is powered from the
  WCD9370's **MIC BIAS1**. Stock Android routes exactly that, and after adding
  the same route to our tree the capture changed from *exact digital zeros* to
  real signal - so the microphone is now powered and producing a data line.
- Capture path, gain, resampling and the transcription server all work.

## What is still broken

The data is garbage because there is no valid PDM clock.

| Evidence | Value |
|---|---|
| `CDC_TX_TOP_CSR_SWR_DMICn_CTL` (0x00C0-0x00CC) | `0x0E` on all four, **never changes** |
| Switching `TX DEC0 MUX` to SWR_MIC and back | register still `0x0E` |
| Field [3:1] decode | 7, which is not a valid divider code (valid: 0,2,4,6,8,10) |
| Vendor device tree | `qcom,dmic-sample-rate = <2400000>` on **va-macro**, and `"TX_AIF1 CAP", "VA_MCLK"` in the routing |

So the TX macro is not the clock source on this board. The vendor clocks the
DMIC from the **VA macro**, and mainline never runs the VA macro at all: the
sound card has only `MultiMedia1/2/3`, no VA backend, and
`va_macro a4a0000.codec: qcom,dmic-sample-rate dt entry missing` in dmesg
because our DTS omits the property.

A driver patch setting the TX macro divider to DIV4 (2.4 MHz) was tried and
removed: the write never executes, because the only path that programs that
register is the DEC mux put-handler, and re-triggering it changes nothing.

## What it will take

Wire a VA capture path, which is a real port rather than a property:

1. Add `qcom,dmic-sample-rate = <2400000>` to the `vamacro` node.
2. Add a capture DAI link: `qai->q6afedai VA_CODEC_DMA_TX_0` ->
   `&vamacro`, platform `q6routing`.
3. A VM capture needs the VA macro's own decimator mux (`VA DMIC MUX0` etc.).
4. UCM: point the capture device at the new PCM and set `MultiMedia3 Mixer
   VA_CODEC_DMA_TX_0`.

Steps 1-3 are device-tree work (a new node, so not `fdtput`-able); step 4 is a
UCM change. The known-good DTB must keep booting, so any rebuilt tree has to be
tested on the SD card first - see the boot rules in `docs/BUILD.md`.

## Volume control on this card (affects every test script)

`amixer` cannot touch this card: `cget`/`cset` abort with
`control.c:427: snd_ctl_elem_info` (rc 134) for every numid except 1, while
`alsactl` works because it uses `ELEM_READ`. All acceptance tooling therefore
drives controls through a stored state file (`alsactl store` / edit / `restore`).

## Nasty details

- `arecord` on `hw:0,2` gets truncated while PipeWire holds the card; use
  `pw-record` as `duo` with `XDG_RUNTIME_DIR=/run/user/1000`, and stop it with
  SIGINT (`timeout -s INT`) so the WAV header is finalised.
- The capture gain is `TX_DEC0 Volume` (0-124; the UCM value is 84).
- Only `hw:0,2` (MultiMedia3 -> `TX_CODEC_DMA_TX_3`) is routed for capture;
  `hw:0,0` and `hw:0,1` open and then fail with `EINVAL`.
