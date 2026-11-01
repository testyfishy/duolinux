# Help wanted

Everything below is measured on the hardware, not inferred. Each item says what
is proven, what is missing, and what would actually settle it. Details live in
the linked docs.

## 1. Microphone: no PDM clock

`docs/MICROPHONE.md`

**Proven:** the mic is powered (the `TX DMIC2 -> MIC BIAS1` route switches the
codec's bias on, which changed the capture from exact digital zeros to real
signal), the pads are muxed (`gpio127/128` = `dmic1_clk`/`dmic1_data`), the
decimator runs (`0x0400`: `0x04 -> 0x24` while capturing), and the capture path
plus transcription work.

**Missing:** the data line only produces a slow DC wander. `SWR_DMICn_CTL`
(0x00C0/0x00C4) is never programmed by mainline, and its bit 0 is read-only
status, not an enable. The vendor enables the clock through
`bolero_clk_rsc_request_clock`, a clock-resource framework mainline does not
have. Android on this device captures through the **TX** macro (`TX DMIC2`);
Retroid's Linux port for the Duo uses the **VA** macro
(`VA_CODEC_DMA_TX_0`, `qcom,dmic-sample-rate`), which we could not reproduce
because audioreach needs SPF firmware that bengal does not ship.

**Would settle it:** the vendor's SM6125 audio-kernel source, the board's
`sound` node from their Android DTS, or a working mainline DMIC sequence from
another SM6125 board.

## 2. Speakers: quiet, and the volume control is dead

`docs/SPEAKERS-NEXT.md`

**Proven:** the amps are at their profile maximum (attenuation register 05 = 11,
-1.4 dB), PLL locked (status 0x0311), codec digital volumes 0 dB, streams routed.
Android's own driver uses the same `min(value + min_vol, max_vol)` arithmetic and
its `mixer_paths.xml` sets no amp controls, so Android's maximum is the same
value - yet it is much louder.

Two separate defects:

- **Volume control does nothing.** `amixer` cannot read or write any control on
  this card (`snd_ctl_elem_info` fails, rc 134) while `alsactl` can, so PipeWire
  applies no gain and the UI slider is inert.
- **The ceiling is real.** The extra loudness is in Android's ADSP: ACDB
  calibration/compression that mainline has no equivalent for. The newer
  audioreach topology exposes `stream*.vol_ctrl*`; bengal's firmware cannot run
  it. A PipeWire limiter chain would be the workaround, but this PipeWire build
  cannot host LV2 nodes (`can't load plugin type 'lv2'`).

**Would settle it:** a working ACDB/COPP calibration path on mainline, or a
PowerWire build whose LV2 filter-chain works, or confirmation of the amp
registers Android actually uses at full volume (we could match them).

## 3. Hardware video (Venus): nodes exist, core never powers

**Proven:** a `videocc-sm6125` clock driver, a `qcom,sm6125-venus` resource set,
the DTS nodes and a hand-authored DTB are all in place and boot. The driver
binds and registers `video0 = qcom-venus-decoder` and
`video1 = qcom-venus-encoder`.

**Missing:** the core never powers up. `venus_gdsc` and `vcodec0_gdsc` read
`off-0` with zero users, `video_cc_venus_clk_src` shows 19.2 MHz but is never
enabled, and the first probe logged `failed to reset venus core` (-ETIMEDOUT).
Any real ioctl fails (`VIDIOC_G_FMT`, encoder `-EINVAL`).

**Would settle it:** the correct `videocc` clock/GDSC table or the power-domain
wiring for SM6125 - the current driver is modelled on `videocc-qcs615.c` and the
vendor's `videocc-trinket.c` register map.

## 4. `pa stop check fail:0x0330`

Both AW88166 amps log this whenever playback stops. Playback works, so it is
cosmetic, but it indicates the amp's interrupt status is not clean after a stop -
possibly I2S-stop ordering.

## 5. Amp volume-control semantics upstream

The upstream `aw88166` control *adds* attenuation, so the ALSA maximum mutes the
amp and PipeWire's 100 % is silence. We invert the mapping locally
(`toolkit/kernel/fix-aw88166-volume-v3.sh`); ROCKNIX fixed the same class of bug
for SM4450. One agreed upstream shape would be better than three forks.

## Also open

- **Repository history** contains a Windows username in early commits; purging
  needs `git filter-repo` and a force-push, so it is an owner decision.
- **No native Steam**: the arm64 client needs LSE atomics this SoC lacks. The
  box64 + Hangover route is untested.
