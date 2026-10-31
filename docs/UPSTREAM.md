# Upstream position

What could be contributed, who to, and what not to bother with. Written after
the 7.2.11 port; the series itself is published in `kernel/patches/7.2.11/`.

## Recommendation

1. **Published, done:** the rebased series lives in this repo so the work is
   reusable against future stable kernels.
2. **Send to ROCKNIX:** the `0032` conflict resolution and a 7.2.11 test report.
   They wrote the series, they carry it across kernel versions, and they have
   other device owners who can test.
3. **Mainline:** optional, slow, and only with the original authors involved.
   Start with the SoC fixes and the board DTS, not the display stack.

## Triage of the series

| Area | Upstreamable | Reality |
|---|---|---|
| sm6125 clk/pinctrl/interconnect fixes, MPM wake controller | **Yes** | Small and self-contained; usually one cycle |
| Board DTS + bindings | **Yes, with work** | `dtbs_check`, a vendor prefix, 1-3 review rounds |
| sm6125 DP controller | Probably | Weeks; must fit the msm DP per-SoC table |
| hx83112a panel variant | Likely | Only if it extends the existing upstream driver instead of copying it |
| bq256xx JEITA / OTG / iindpm | Maybe | The driver is upstream; these go as separate patches |
| cx221x fuel gauge | Maybe | New driver + binding; check for an existing Cellwise driver first |
| ADSP / LPASS audio fixes | Case by case | Real fixes yes, board hacks no |
| wl818s DP→MIPI bridge + MCU backlight | Hard | New binding, vendor prefix, undocumented MCU protocol; months if ever |
| WCN3990/3950 workarounds | Mostly no | Maintainers want a root cause, not a workaround |
| PSCI suspend fallback | No | It is a hack |
| DPU rotator / qseed / smart DMA / VBIF | **Never in this form** | Downstream design; would need a ground-up rewrite |
| rsinput gamepad | Not as-is | Needs to become a proper serdev input driver |

## Why a board DTS alone is not worth much

Without the panel, bridge and DP support, mainline boots a headless board: USB,
storage, maybe Wi-Fi. Nobody runs a handheld like that. The DTS is worth
submitting as part of a series with the SoC fixes, because it then gets built
and checked against every future change to the sm6125 dtsi - which is the churn
that breaks out-of-tree DTS files on every rebase.

## Authorship and sign-off

- Kernel code is GPLv2; redistributing it, including here, is fine.
- `Signed-off-by` (DCO) may only be added by someone entitled to sign that code.
  You cannot sign another person's patch as your own.
- 41 of the 79 source patches carry a `From:`/`Author:` line and keep it. The
  other 38 carry none: authorship is unknown, and they must not be submitted
  upstream without establishing who wrote them.

## Draft message to ROCKNIX (not sent)

> Subject: SM6115 series on 7.2.11 - one conflict fix and a test report
>
> I run Debian on the Retroid Pocket Duo Lite and rebuild your
> `devices/SM6115/patches/linux` series onto current stable kernels.
> On 7.2.11, 78 of the 79 patches rebase cleanly through `git am -3`; the only
> real conflict is `0032` (bq256xx software JEITA), because 7.2.11 added
> `devm_add_action_or_reset(bq, bq256xx_charger_reset)` and the usb2/usb3
> `usb_register_notifier()` calls at the exact point where the patch inserts its
> JEITA init.
>
> I kept both, with the JEITA init *before* the notifier registration. Two
> reasons: a failing `devm_add_action_or_reset` then cannot leave notifiers
> registered against memory devm is about to free, and the JEITA init stays
> ahead of `bq256xx_irq_handler_thread()`, which calls
> `mod_delayed_work(&bq->jeita_work, 0)` on a VBUS change.
>
> Verified on the device with 7.2.11: both panels, 3 blank/unblank cycles, lid
> suspend/resume with `suspend_stats` clean, charger attach/detach plus charging
> at ~1.7 A, audio card, both remoteprocs, 0 failed units.
>
> The rebased series is published at <repo>/kernel/patches/7.2.11 with the
> original `From:`/`Date:` headers preserved. Happy to test whatever you carry
> forward.

## Not doing

- submitting the DPU rotator, the PSCI fallback or the Wi-Fi workarounds
- rewriting rsinput
- submitting patches whose author cannot be established
- keeping the port private
