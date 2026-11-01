# Level1Techs post

## Where

Level1Techs has no standalone handheld category. The two sensible places:

- **The "Handheld gaming" thread** - <https://forum.level1techs.com/t/handheld-gaming/145350>
  Long-running, gets handheld traffic. Good for a short "here is what I did,
  anyone know X?" post.
- **A new topic in Gaming** - more visible if the thread is quiet, and the post
  is substantial enough to stand alone.

Start in the thread. It reads as a contribution rather than a support request,
and the regulars there are the ones who know these devices.

## The post

> **Retroid Pocket Duo Lite running mainline Debian - two audio gaps left**
>
> I've been putting mainline Linux on the Pocket Duo Lite (the SM6125 model, not
> the QCS8550 Duo) for a while now. It's at the point where it's a decent little
> dual-screen machine: both panels and touch, Plasma, gamepad as the mouse and
> keyboard, on-screen keyboard, Wi-Fi, BT, lid suspend, fan, chargers, Tailscale,
> Moonlight streaming. Kernel is 7.2.11 with the ROCKNIX SM6115 patches rebased
> and a pile of my own fixing.
>
> Everything's here if you want to look or yell at it:
> https://github.com/testyfishy/duolinux
>
> What's left, and where I'm stuck:
>
> - **Mic.** Works in the stock Android build, so it's not the hardware. In
>   mainline the LPASS TX macro's DMIC clock never gets enabled - the vendor
>   driver does it through a clock-resource layer mainline doesn't have. I've
>   confirmed the codec's MIC BIAS1 is powered and the pins are muxed, so it's
>   the clock, not the routing.
> - **Speaker level.** Both AW88166 amps work and are already at their profile
>   maximum, but it's much quieter than Android. Android sets no amp controls in
>   its mixer and its driver uses the same volume maths, so the difference has to
>   be the ADSP calibration (there's an acdbdata folder on the vendor partition).
>   I can't load that from mainline.
> - **Volume slider** does nothing because the card's ELEM_INFO is broken -
>   amixer aborts on every control. Cosmetic, but annoying.
> - **Venus** (hardware video) is nearly there: clock driver, DTS and DTB are in,
>   decoder and encoder nodes register, but the core never powers up - both
>   GDSCs stay off. The videocc table is the suspect.
>
> One thing worth saying plainly: a lot of this was written with DeepSeek helping
> me - I'm not a kernel developer, I just refused to leave the device on Android.
> So if any of the above has an obvious answer I've missed, that's why.
>
> Any SM6125 audio or video people here? Even "your videocc offsets are wrong"
> would be useful.

## Notes before posting

- No screenshots needed; the repo has the detail if anyone asks.
- If someone offers to help with the mic, point them at `docs/MICROPHONE.md` and
  the Retroid request in `docs/OUTREACH.md`.
- Don't paste dmesg in the post; offer it in a reply.
