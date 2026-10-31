# Performance and resource use

Measurements taken on the device (SM6125, Debian 13, Plasma 6.3.6, 5.3 GiB RAM).

## Where the memory actually is

Unique memory (PSS), so shared pages are not double counted:

| Process | PSS |
|---|---|
| plasmashell | 296 MiB |
| kwin_wayland | 84 MiB |
| kded6 | 38 MiB |
| Xwayland | 35 MiB |
| tailscaled | 34 MiB |
| Discover notifier | 31 MiB |
| polkit agent | 27 MiB |
| kaccess | 27 MiB |
| **all five Python daemons** | **55 MiB** |

System total 5.3 GiB, 1.4 GiB used, 4.0 GiB available, swap untouched.
The device is **98.2 % idle**; the busiest process is `inputplumber` at ~4.4 % of
one core.

## duo-fan: the one real waste

The daemon polled every 2 s forever, logged on every poll (~43k journal lines a
day), wrote `pwm1`/`pwm1_enable` on every tick even when unchanged, and re-globbed
every thermal zone each time.

The control law was not touched. What changed:

- the averaging window is **time-based** (16 s), so a slower poll cannot silently
  stretch it and change the control behaviour;
- polling adapts: **2 s** while the fan runs or the hottest zone is within 10 C of
  the start point, **5 s** otherwise - never slower, because a burst can heat this
  SoC by several degrees per second;
- sysfs is written only on change, and re-read every 45 s and re-asserted if
  something reset it (resume from suspend clears `pwm1_enable`);
- the journal gets a line only when state or pwm meaningfully changes, plus a
  15 minute heartbeat;
- thermal zones are opened once and re-read with `pread`.

| | before | after |
|---|---|---|
| CPU | 0.50-0.63 % of one core | **0.124 %** |
| journal lines | ~30/min | ~3/min while ramping, ~1 per 15 min steady |
| PSS | 6.2 MiB | 6.2 MiB |

Behaviour was verified by replaying a synthetic warm-up/plateau/cool-down trace
through both implementations (`toolkit/kernel/test-fan-replay.py`): same start
time (210 s), same peak pwm (90), worst difference while running 3 pwm across 345
compared ticks.

## Decisions taken

- **No consolidation of the daemons.** Merging backkey, fan, lid and
  brightness-guard saves roughly 12-15 MiB (0.3 % of RAM, because the interpreter
  and library pages are already shared) and costs coupling: a bug in a shared loop
  would stall input, and one crash would take down lid suspend. If it is ever
  merged, it should be one `selectors` event loop, not threads, and the fan should
  stay in its own process.
- **No C rewrite.** Nothing measured justifies it: the daemons are 55 MiB and
  ~1 % of one core in total. The interpreter baseline is ~5-6 MiB each; the tray's
  cost was GTK, not Python.
- **Tailscale tray is upstream's now.** Tailscale ships `tailscale systray`
  (Go, ~25 MiB); our GTK client was 32 MiB. The installer prefers the upstream
  binary and keeps ours only as a fallback for releases without the subcommand.
- **Kernel is separate.** The custom 7.2.11-nf kernel and its module tree are
  unaffected by any of this.

## Still on the table (not done)

- **Discover notifier** - 31 MiB PSS for an update badge. Disable with a
  `~/.config/autostart` override (`Hidden=true`) if updates are checked manually.
- **kaccess** - 27 MiB for accessibility shortcuts. Only worth removing if those
  features are unused; the on-screen keyboard does not need it.

These are the two biggest cheap wins left, and neither is ours to break.

## How to reproduce the numbers

| Script | What it reports |
|---|---|
| `toolkit/kernel/cpu-profile.py` | system busy/idle and per-process CPU over a window |
| `toolkit/kernel/pss-probe.sh` | unique memory per process |
| `toolkit/kernel/python-cost-probe.sh` | the Python daemons specifically |
| `toolkit/kernel/measure-fan-opt.sh` | fan CPU, journal rate, PSS over 3 minutes |
| `toolkit/kernel/test-fan-replay.py` | old vs new control law on a temperature trace |
| `toolkit/kernel/audit-daemons.sh` | journal rate and lifetime CPU per daemon |
