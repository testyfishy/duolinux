# How to reach Retroid about the Duo Lite

## 1. Where to send it

Retroid's own About page lists two addresses:

| Address | Use |
|---|---|
| **linux_support@goretroid.com** | **Primary.** It exists specifically for this. |
| sales@goretroid.com | General customer service; CC it only if the first bounces. |

Not GitHub: `RetroidPocket/linux` has issues and discussions disabled, and a PR
that only asks a question gets closed.

## 2. Before you write: rules that decide whether it is answered

1. **One message, one page.** Support inboxes triage by length.
2. **Name the exact model and SoC in the subject.** "Pocket Duo Lite (SM6125)"
   - not "the Duo" - because "eliza" is the QCS8550 model and half their
   documentation is about that one.
3. **Lead with what works.** It proves you are not asking them to debug a broken
   unit, and it frames the rest as a small gap rather than a complaint.
4. **Say plainly that you may be wrong.** You are asking for their
   configuration, not reporting their bug.
5. **Number the asks, one sentence each, one per item.** Three at most.
6. **Link, do not attach.** A public repo link they can skim beats a 200-line
   log in the body.
7. **No legal language.** "Corresponding source" reads as a demand; "the
   configuration values that are already in your trees" reads as a request.
8. **Say what you will do with the answer** (test it, report back, publish the
   fix). That makes replying worthwhile.
9. **Expect one follow-up.** If there is no reply in 10 days, reply once to the
   same thread with a one-line nudge; do not open a new mail.

## 3. The message, line by line

> **Subject: Pocket Duo Lite (SM6125) - mainline Linux bring-up, and a question about the audio path**

*Why:* exact model and SoC; "bring-up" signals engineering, not a support
complaint; "a question about the audio path" is concrete and matches the inbox
that handles Linux.

> Hello,
>
> I own a Pocket Duo Lite and have been running mainline Linux on it for a few
> months.

*Why:* one line of identity. "I own" matters - you are a customer, not a
stranger asking for free work.

> Most of it works: both panels and touch, Wi-Fi, Bluetooth, lid suspend, fan
> control, the chargers, gamepad input, the on-screen keyboard, and audio
> playback.

*Why:* establishes credibility and shows the audio question is the residue, not
the whole device.

> The kernel patches and my notes are here: https://github.com/testyfishy/duolinux
> - the Duo's `linux` and `alsa-ucm-conf` repos were a big help.

*Why:* one link, and credit where it is due. This is the line that makes them
read the rest.

> Three things I could not work out from the firmware, and I would rather ask
> than guess wrong:

*Why:* humble framing, and it tells them the answer is short.

> 1. **Microphone.** It records correctly in the shipped Android build, so the
> hardware is fine. In my kernel the LPASS TX macro's DMIC clock never gets
> enabled. Could you tell me which macro and which DMIC pair the on-board
> microphone is wired to, or point me at the `sound` node in the Duo Lite
> device tree?

*Why:* states the evidence (works in Android), gives one specific ask, and
offers them an easy answer ("it's DMIC2 on the TX macro") instead of a design
discussion.

> 2. **Speaker level.** Both AW88166 amps work and are at their profile maximum
> (attenuation register 05 = 11), yet the same track is much louder in Android.
> I found `/vendor/etc/acdbdata/QRD/*.acdb` on the device. Is there a
> calibration or COPP setting for the speaker path that Android applies and
> that I should reproduce? I may be looking in the wrong place entirely - if
> there is a simpler explanation, I would be glad to hear it.

*Why:* this is the honest version. It gives the measurement, names the file you
found, and explicitly invites them to say you are wrong. That last clause is
what turns a report into a conversation.

> 3. **Video.** I am bringing up Venus on SM6125: `videocc@5b00000`, a
> `qcom,sm6125-venus` resource set modelled on sc7180, and the vendor's IOMMU
> stream IDs. The driver binds and creates decoder/encoder nodes, but the core
> never powers up (both GDSCs stay off). If the SM6125 `videocc` configuration
> is shareable, that would likely finish it.

*Why:* the most technical item last, with the exact symptom. Gives them a
keyword (`videocc`) to route internally.

> I am happy to test anything you point me at, and to share register dumps,
> logs or the patches in return. I am only after configuration values that are
> already in your trees - not firmware blobs.

*Why:* offers reciprocity, and pre-empts the usual "we cannot share
proprietary files" response.

> Thanks for publishing the Linux repos, and for keeping the Duo Lite
> repairable.
>
> Kind regards,
> *[name]*
> *[device: Pocket Duo Lite, 6 GB, purchased <month>]*

*Why:* a purchase detail on the last line helps them place you as a customer
without making it a support ticket.

## 4. What to link, never attach

- `https://github.com/testyfishy/duolinux` - the repo front page.
- Optionally `docs/MICROPHONE.md` and `docs/SPEAKERS-NEXT.md`, which contain
  every measurement so their engineer can check the claims without asking you
  for more.

## 5. What not to write

- "Your drivers are broken." The amp and codec drivers are fine; the gap is
  configuration.
- "Please send the kernel source." It is already published.
- A wall of `dmesg`. One line of error is enough; the rest is in the repo.
- Anything about ROCKNIX, other vendors, or their Android build being wrong.
