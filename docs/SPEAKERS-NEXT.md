# Speakers: why they are quiet, and what is left

## Measured state (stable across reboots)

| Check | Result |
|---|---|
| Attenuation register 05 | `0x800B` = 11 (-1.4 dB), the profile's own maximum |
| Status register 01 during playback | `0x0311`: PLL locked, clocks stable |
| ACF profile | byte-identical to the vendor partition's copy; every register it lists matches the live chip |
| Route | `PRI_MI2S_RX Audio Mixer MultiMedia1` = true, speaker switches true |
| Codec digital volumes | `RX_RX0..2 Digital Volume` = 84 = 0 dB |
| Sink volume 20 % vs 100 % | **no audible difference** |
| Amp control 0 vs 1023 | control 0 silences the output, so the amps are in the path |

Two independent defects:

1. **The volume control does not reach the hardware.** Sink volume changes have
   no audible effect, and `amixer` cannot read or write any control on this card
   (`snd_ctl_elem_info` fails, rc 134) while `alsactl` can. PipeWire's mixer
   integration uses the same broken path, so it silently applies no gain.
   Fixable, but it would not add loudness: the amp is already at its maximum.
2. **The amps are at their profile maximum and it is still quiet.** Nothing in
   the mixer, the DTB or the ACF has headroom left.

## What the public search found (advisor, 2026-10-31)

- No public report or fix for "AW88166 audible but quiet" on any mainline
  platform.
- ROCKNIX's Duo Lite DTS (commit 48b98a02d7) sets `awinic,audio-channel`,
  `awinic,sync-flag` and per-amp `reset-gpios`. **Our booting DTB already has
  all three, and our driver handles all three** (channel parsed after the default
  assignment; `devm_gpiod_get_optional(dev, "reset", ...)`), so there is nothing
  to copy.
- The ROCKNIX RK3566 "start the amp once the bit clock runs" patch fixes
  PLL-lock failures at start; ours locks fine.
- Awinic's vendor driver has no boost/Class-H setting that mainline lacks.

## Where the gap must be

Stock Android's `mixer_paths.xml` sets **no** amp controls, and its
`aw883xx_dlkm.ko` computes the same `min(value + min_vol, max_vol)`, so Android's
amp is also at attenuation 11. The difference therefore lives in the **ADSP
stream path**, not in the amps:

- Android's stack (and Retroid's newer Linux topology) exposes
  `stream*.vol_ctrl*` DSP volume controls; our older `q6asm` topology exposes
  none, so the DSP applies whatever fixed gain it defaults to.
- The other candidate is ACDB calibration, which the vendor HAL applies and
  mainline has no equivalent for.

## Next step (large, deliberate)

Porting to the newer **audioreach / `q6apm`** topology is what would give us the
stream volume and gain controls - the same topology Retroid's eliza DTS uses
(`q6apmbedai` + `q6apm`). That is a sound-card rewrite, not a DTS tweak, and it
is also the path that would solve the microphone (`VA_CODEC_DMA_TX_0` capture
through the VA macro).

Both remaining audio defects therefore share one root cause with one fix: the
newer DSP topology. See also `docs/MICROPHONE.md`.
