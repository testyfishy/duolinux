# Asking Retroid (and ROCKNIX) for the Duo Lite data

## How to reach them

- **GitHub issues are disabled** on `RetroidPocket/linux` and on ROCKNIX's
  `distribution` repo (`has_issues: false`), so an issue cannot be opened. The
  only GitHub route would be a pull request, which is not appropriate for a
  question.
- Realistic channels: Retroid support email (`support@goretroid.com`) and the
  Retroid/ROCKNIX Discord. ROCKNIX also has a Discord and no issue tracker.

## What we already have

- The complete SM6115 ROCKNIX port working on the Duo Lite: both panels,
  touch, Wi-Fi, Bluetooth, suspend/lid, fan, chargers, audio playback, the
  on-screen keyboard, gamepad mapping, streaming, and a published 79-patch
  kernel series (`kernel/patches/7.2.11/`).
- Evidence that the microphone works in stock Android and that its supply is
  the codec's MIC BIAS1, but that mainline never clocks it.
- A measured speaker/amp analysis: the AW88166s are at their profile maximum,
  and the loudness difference from Android is DSP-side, not mixer-side.
- A Venus video port mid-flight: clock driver, DTS, DTB and driver resources in
  place; the core still does not power up.

## Draft message

> Subject: Retroid Pocket Duo Lite (SM6125) - mainline Linux progress and a
> request for the board's audio/video configuration
>
> Hello,
>
> I have been running mainline Linux on the Pocket Duo Lite (the SM6125 /
> QCS6125 model, not the QCS8550 "eliza" Duo) and have most of it working on a
> 7.2.11 kernel: both panels and touch, Wi-Fi, Bluetooth, suspend via the hall
> sensor, fan control, chargers, gamepad input, an on-screen keyboard, and
> audio playback. The kernel patch series is published at
> <https://github.com/testyfishy/duolinux> together with the investigation
> notes.
>
> Three things remain, and your own data would save a lot of guesswork:
>
> 1. **Microphone.** It records correctly in the shipped Android build, so the
>    hardware and its supply are fine. In mainline the LPASS TX macro's DMIC
>    clock is never enabled (`SWR_DMICn_CTL` stays at its reset value, bit 0 is
>    read-only status). Android appears to clock it through the vendor's
>    bolero clock-resource layer. Could you share the `sound` node and the
>    DMIC/VA-macro configuration from the Duo Lite's Android device tree, or
>    confirm which macro and which DMIC pair the on-board microphone is wired
>    to?
> 2. **Speaker level.** The two AW88166 amps are working and at their
>    profile maximum (attenuation register 05 = 11), yet the same content is
>    much louder in Android. Android's mixer sets no amp controls and its
>    driver uses the same volume arithmetic, so the difference must be in the
>    ADSP. Is there an ACDB calibration or COPP setting for the speaker path
>    that we should reproduce?
> 3. **Video.** We are bringing up Venus on SM6125: `videocc@5b00000`, a
>    `qcom,sm6125-venus` resource set modelled on sc7180, and the IOMMU
>    stream IDs from the vendor device tree. The driver binds and creates
>    decoder/encoder nodes, but the core never powers (both GDSCs stay off).
>    If you have the SM6125 `videocc` configuration or the correct stream IDs,
>    that would likely finish it.
>
> I am happy to share everything I have - the patch series, the register dumps,
> and the notes - and to test anything you can point me at. I am not asking for
> vendor blobs, just the configuration values that are already in your device
> trees.
>
> Thank you for publishing the `RetroidPocket/linux` and `alsa-ucm-conf` repos;
> the Duo's DTS and UCM were genuinely useful for this work.

## Notes before sending

- Do not include the Windows username, LAN addresses or keys; the repo is
  public and scrubbed, keep the message the same.
- Link the published repo and the two docs (`docs/MICROPHONE.md`,
  `docs/SPEAKERS-NEXT.md`) rather than pasting dumps.
- For the SM6125 question specifically, ask for the *Duo Lite* configuration:
  "eliza" is the QCS8550 Duo and its files do not describe our board.
