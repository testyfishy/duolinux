# Suspend, lid and idle

## Who actually suspends the device

Two mechanisms want to handle the lid, and only one of them acts:

| Component | Role | State |
|---|---|---|
| `duo-lid.service` (`/usr/local/bin/duo-lid`) | watches `gpio-keys-lid`, debounces, calls suspend | **active, enabled** |
| `systemd-logind` | `HandleLidSwitch=suspend`, `HandleLidSwitchExternalPower=suspend` | configured, but inhibited |
| PowerDevil | holds `handle-lid-switch` with mode `block` | **does nothing** |

PowerDevil holds the lid inhibitor but suppresses its own action:

```
org.kde.powerdevil: Lid action was suppressed because an external monitor is present
```

The bottom panel (`DP-1`) is seen as an external monitor, so KDE decides a lid event
should not sleep the machine. That is not configurable away from inside KDE without
lying about the monitor, so `duo-lid` performs the suspend directly through logind's
`Suspend` method, which the inhibitor does not block.

**Consequence:** if `duo-lid` stops, the lid does nothing at all. Check
`systemctl status duo-lid` first when lid behaviour looks wrong.

## Attempt to use PowerDevil instead of duo-lid (failed on 6.3.6)

PowerDevil has an upstream switch for exactly this problem:
`inhibitLidActionWhenExternalMonitorPresent`. The plan was to set it to false,
set `LidAction` to Sleep, and delete our daemon.

It does not work on Plasma 6.3.6. With `duo-lid` disabled and the config proven
to be what KDE reads:

```
kreadconfig6 --file powerdevilrc --group AC --group LidAction --key action
  -> 1                                    (sleep)
kreadconfig6 --file powerdevilrc --group AC --key inhibitLidActionWhenExternalMonitorPresent
  -> false
journal: org.kde.powerdevil: Lid action was suppressed because an external monitor is present
```

Closing the lid did nothing. Both profile files were checked
(`powerdevilrc` and `powermanagementprofilesrc`, the latter only carries the
Plasma 6 migration marker), the keys are in the active `AC` profile, and
PowerDevil was restarted before the test.

So on this version the external-monitor suppression is applied regardless of the
setting. `duo-lid` was re-enabled and remains the working path until this is
fixed upstream; the PowerDevil keys are harmless and can stay.

## What a correct lid cycle looks like

```
duo-lid: lid closed, waiting before suspending      (2 s debounce)
duo-lid: lid still closed, suspending
systemd-logind: The system will suspend now!
kernel: PM: suspend entry (deep)
kernel: PM: suspend exit
systemd-logind: Lid opened.
systemd: System returned from sleep operation 'suspend'.
```

## Do not trust dmesg timestamps for sleep duration

`CLOCK_MONOTONIC` does not advance during deep sleep, so dmesg shows:

```
[  412.504725] Disabling non-boot CPUs ...
[  412.528314] Enabling non-boot CPUs ...
```

even when the device slept for 23 seconds of wall time. Use
`/sys/power/suspend_stats/success` and `last_hw_sleep` instead, or watch the device
from outside:

```
# on the host
ping -i1 <device-ip>
# on the device
rtcwake -m mem -s 15
```

A real suspend makes the device vanish from the network for the whole interval and
reconnect afterwards. A display-only blank keeps answering ping. Measured here:
down at 12:24:27, up at 12:24:48, `suspend_stats.success` incremented.

## Idle must never suspend

| Setting | Value |
|---|---|
| `logind IdleAction` | `ignore` |
| PowerDevil `[AC][SuspendSession] idleTime` | `0` |
| PowerDevil `[Battery][SuspendSession] idleTime` | `0` |

With the lid open the device stays awake indefinitely. If it suspends with the lid
open, check in this order:

1. `journalctl -b | grep -E "duo-lid|will suspend"` - was it `duo-lid` (lid actually
   closed) or logind acting alone?
2. If logind acted alone, something called `Suspend()` directly: check
   `systemd-inhibit --list` for a new player, and PowerDevil's idle timers.
3. `cat /proc/bus/input/devices` and confirm the lid switch reports open
   (`evtest /dev/input/event3`).

## Scripts

- `pre-lid-test.sh` - baseline: charging, lid policy, inhibitors, suspend count
- `diag-lid-test.sh` - what happened on the last lid cycle and who owns the decision
- `check-lid-history.sh` - every suspend this boot against `duo-lid`'s own log
- `test-suspend-external.sh` - RTC-alarm suspend while pinging from the host
