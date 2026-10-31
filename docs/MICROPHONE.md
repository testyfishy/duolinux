# Microphone

**Status: the hardware works (verified in stock Android); mainline was missing the
supply route. Fix is in the tree, verification pending.**

## What was wrong

The stock Android image on this device routes the digital microphones like this
(`dtbo` overlay, `trinket-idp-snd-card`):

```
"TX DMIC2", "Digital Mic2", "TX DMIC2", "MIC BIAS1",
"TX DMIC3", "Digital Mic3", "TX DMIC3", "MIC BIAS1",
```

So the DMIC pair is **TX DMIC2/3** (the TX macro, as mainline expects) but it is
powered from the **WCD9370's MIC BIAS1** — the codec's microphone bias is the
microphone's supply.

The mainline card's `audio-routing` array only had the speakers and the headset
(`AMIC2`/`MIC BIAS2`). With no route from a DMIC input to `MIC BIAS1`, that bias
is never switched on by DAPM, the mics get no power, and their data line sits at
a constant level: **every DMIC input read exact digital zeros**.

This is the same spelling mainline uses on other boards with this codec
(`sm8450-hdk`, `sm8550-mtp`, `sm8550-qrd`): `"TX DMICn", "MIC BIASm"`.

The pin side was already right: `gpio127/128` are muxed as `dmic1_clk`/`dmic1_data`
(pair 1), which the TX macro numbers DMIC2 and DMIC3.

## The fix

`toolkit/kernel/fix-dmic-bias.sh` adds to the board DTS:

```dts
"TX DMIC2", "MIC BIAS1",
"TX DMIC3", "MIC BIAS1";
```

`toolkit/kernel/install-nf.sh` installs the kernel **and the DTB** — the device
tree is loaded from the FAT boot partition
(`dtbs/qcom/sm6125-retroid-pocket-duo-lite.dtb`), not from the kernel image, so
a DTS change only takes effect when that file is replaced too.

## Evidence that led here

| Observation | Meaning |
|---|---|
| Mic records fine in stock Android | hardware, bias and wiring all exist |
| DMIC0/2/3, DMIC4-7 read **exact digital zero** | decimator clocked, no signal on the data line |
| DMIC1 reads junk (~5-20 zero crossings/s) | gpio126 is unmuxed, so that pad floats |
| TX macro registers while streaming: MCLK on (9.6 MHz), DEC0 muxed to DMIC2, SWR bit clear | the digital path is configured correctly |
| 32-bit capture is MSB-aligned (low halfword always zero) | not a word-width problem |
| Analog WCD9370 route (AMIC2/INP2) reads a floating ADC | no analog mic on that input |
| Vendor DTB: `TX DMIC2/3` ← `MIC BIAS1`, `qcom,tx-dmic-sample-rate = <0x249f00>` (2.4 MHz) | the missing route and the intended PDM clock |

## Where the vendor configuration came from

The Android partitions are intact on the same eMMC (`mmcblk1`):

| Partition | Contents |
|---|---|
| `boot_a` | Android boot image (kernel, no FDT inside) |
| `dtbo_a` | 18 device-tree overlays, including the audio routing above |
| `vendor_boot_a` | 3 base device trees (Trinket / TRINKETP) |

`toolkit/apps/extract-android-dtb.sh` pulls them, finds every FDT by magic,
splits and decompiles them; `survey-vendor-dtb.sh` and `show-vendor-audio.sh`
print the audio plumbing.

## If the fix is not enough

Two further candidates, in order:

1. **PDM clock rate.** The vendor asks for `qcom,tx-dmic-sample-rate = <0x249f00>`
   (2.4 MHz). Mainline's TX macro writes `CDC_TX_SWR_DMIC_CLK_SEL_MASK` to 0 and
   reads back `0x0E`, so the divider is whatever the reset value means. If the
   mics stay silent after the bias fix, this is the next thing to set.
2. **Pinctrl ownership.** The vendor hangs the DMIC pinctrl off the codec node
   (`qcom,cdc-dmic23-gpios`), while our DTS puts it on the sound node. Only
   matters if the pads turn out not to be held in the DMIC function while
   recording.

## Nasty details worth remembering

- `arecord` on `hw:0,2` gets **truncated** while PipeWire holds the card (a 45 s
  request produced 8 s). Use `pw-record` as the desktop user
  (`XDG_RUNTIME_DIR=/run/user/1000`), or stop PipeWire first.
- `amixer` `sget`/`cget` **by name can abort**; use `amixer -c0 controls` to list
  and `cset numid=N` to set. The capture gain is `TX_DEC0 Volume` (0-124, UCM
  wants 84); the driver's read-back is unreliable, so judge by captured level.
- The hardware negotiates `S24_LE` at 48 kHz even when asked for s16; that is
  normal.
- Only `hw:0,2` (MultiMedia3 -> `TX_CODEC_DMA_TX_3`) is routed for capture;
  `hw:0,0` and `hw:0,1` open and then fail with `EINVAL`.
