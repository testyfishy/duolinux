# Reaching out about the Duo Lite

## What can and cannot be sent from here

- **I cannot send anything**: no mail account, and both vendor repos have
  **issues and discussions disabled** (`RetroidPocket/linux`,
  `ROCKNIX/distribution`). Only pull requests are open, and a PR that contains
  nothing but a question reads as spam.
- So the message below is drafted for **you** to send - by email to Retroid, or
  pasted into a PR description if you prefer that route.

## Asking Retroid (enthusiast tone, not legal)

The tone matters: this is an owner of their hardware asking for configuration
values, not a licence demand. The kernel source is public; what is genuinely
useful and not published is the **device-specific configuration** (device trees,
ACDB calibration, DMIC/videocc wiring).

> Subject: Pocket Duo Lite (SM6125) - mainline Linux progress, and a request for
> the board's audio/video configuration
>
> Hello,
>
> I own a Pocket Duo Lite and have been running mainline Linux on it for a
> while - 7.2.11, with both panels and touch, Wi-Fi, Bluetooth, lid suspend,
> fan control, chargers, gamepad input, an on-screen keyboard and audio
> playback all working. I have published the patch series and my notes at
> <https://github.com/testyfishy/duolinux>; the Duo's `linux` and
> `alsa-ucm-conf` repos were genuinely useful along the way.
>
> Three things are left, and I suspect your own device configuration would
> answer them faster than I can reverse-engineer from the firmware:
>
> 1. **Microphone.** It works in the shipped Android build, so the hardware is
>    fine, but in mainline the LPASS TX macro's DMIC clock is never enabled.
>    Could you share the `sound` node and DMIC configuration from the Duo
>    Lite's Android device tree, or confirm which macro and DMIC pair the
>    on-board microphone uses?
> 2. **Speaker level.** The two AW88166 amps work and are at their profile
>    maximum, but the same content is much louder in Android. I found
>    `/vendor/etc/acdbdata/QRD/*.acdb` on the device - is there a calibration
>    or COPP setting for the speaker path that I should be reproducing in
>    Linux?
> 3. **Video.** I am bringing up Venus on SM6125 (`videocc@5b00000`, a
>    `qcom,sm6125-venus` resource set, the vendor's IOMMU stream IDs). The
>    driver binds and creates decoder/encoder nodes, but the core never powers
>    up. If the SM6125 `videocc` configuration is something you can share, that
>    would probably finish it.
>
> I would be glad to test anything you point me at, and to share the register
> dumps and notes in return. I am only after configuration values that are
> already in your trees - not firmware blobs.
>
> Thanks for publishing the Linux repos and for keeping the Duo Lite
> repairable.

Send to Retroid support (`support@goretroid.com`) or post as the body of a PR
framed as "documentation: notes from mainline bring-up" if that feels more
natural.

## Asking linux-arm-msm

Searched: there is **no existing thread** on SM6125 videocc or DMIC clocking to
reply to, so a cold question would be exactly the "knocking on doors" you want
to avoid. What is expected there is a **patch series with a cover letter**, not
a question. The practical order:

1. Finish the videocc driver so it is a clean patch (it already compiles).
2. Write the cover letter as: what works, what does not, the exact evidence
   (`venus_gdsc off-0`, `video_cc_venus_clk_src` never enabled, reset -ETIMEDOUT,
   the vendor node from `dtb-01.dts`), and the question embedded as "what is the
   correct SM6125 videocc table?".
3. Only then post to `linux-arm-msm@vger.kernel.org`.

That way the first contact is a contribution with a specific question, which is
what maintainers expect and answer.

## Why the ACDB thing is not simply "fixed"

The `/vendor/etc/acdbdata/QRD/*.acdb` files are a **closed binary calibration
database consumed by the ADSP firmware**, not a config file. Android's HAL
loads the relevant calibration into the DSP's COPP stage, which applies
equalisation, multiband compression and a limiter - that is where the extra
perceived loudness comes from.

Mainline's `q6asm` frontend never loads ACDB and exposes no COPP parameters, so
there is nothing to point at the files. Reproducing it means either implementing
ACDB/COPP in the kernel (a feature, not a setting) or doing the equivalent
processing in userspace - and the userspace route is blocked here because this
PipeWire build cannot host LV2 filter nodes (recorded in
`docs/SPEAKERS-NEXT.md`).

So it is not a switch that was missed; it is a missing processing stage.
