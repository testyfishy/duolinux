## Speakers: next lead is Retroid's own Linux port

Retroid publishes both a Linux kernel (`github.com/RetroidPocket/linux`, branch
`retroidpocket/v7.3`, device codename **eliza** = Pocket Duo) and its UCM
(`RetroidPocket/alsa-ucm-conf`, branch `retroidpocket/v1.2.16`). Their
`ucm2/RetroidPocket/ELIZA/` directory is the working reference for a board with
the same AW88166 amps, and it shows two things we do not do:

1. **DSP stream volumes.** Their BootSequence sets
   `stream0.vol_ctrl0 MultiMedia1 Playback Volu` to 100%. Our SM6125 card has no
   `stream*.vol_ctrl*` controls at all, i.e. our QDSP6 path has no stream gain
   stage. That is a plausible source of the loudness gap.
2. **VA-macro capture for the on-board mic**, with `qcom,dmic-sample-rate` and a
   `VA_CODEC_DMA_TX_0` DAI link (`va-dai-link`, codec `&lpass_vamacro 0`).

Their DTS also differs from ours in the amp nodes: `awinic,audio-channel`,
`awinic,sync-flag`, and per-amp `reset-gpios`.

**Do next:** read `eliza-retroidpocket-common.dtsi` and
`ucm2/RetroidPocket/ELIZA/HiFi.conf` from those repos and port the stream-volume
and amp properties. The local copies are fetched by
`toolkit/apps/fetch-retroid-dts.sh`; the UCM clone is at `~/retroid-ucm`.

## Speakers: measured state (unchanged)

The amp applies the vendor ACF profile exactly - every register the ACF lists
matches the live chip during playback - and sits at attenuation 11 (-1.4 dB),
the vendor's own maximum. So the quietness is not a missing mixer setting on the
amp; it is upstream (DSP gain/calibration) or the hardware itself.
