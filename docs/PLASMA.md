# Plasma session on the Duo Lite

The desktop is Plasma 6 (Wayland) started by `startplasma-wayland`, which hands the session to
systemd's user manager. Everything Plasma runs - kwin, kded6, plasmashell, PowerDevil - is then a
user unit. That detail matters more than it looks; see the next section.

## Never start plasmashell by hand

Starting `plasmashell` manually from an SSH shell looks harmless and is not. It inherits the SSH
environment, which lacks `XDG_CURRENT_DESKTOP`, and the consequence is a permanent KSycoca rebuild
storm that pins one core at 25-45 % and makes Kickoff, the Icons-only Task Manager and the classic
task manager all look "broken".

The chain, from the KService source (v6.3.0):

1. `KSycocaPrivate::needsRebuild()` returns true when the expected list of "extra files" differs
   from the one stored in the cache header. That comparison is silent: there is no log line.
2. The expected list comes from `KMimeAssociations::mimeAppsFiles()`, which reads
   `XDG_CURRENT_DESKTOP` and adds `<desktop>-mimeapps.list` for each entry.
3. `/usr/share/applications/kde-mimeapps.list` exists on this image, so a process with
   `XDG_CURRENT_DESKTOP=KDE` expects that file and a process without it does not.
4. plasmashell without the variable wrote a header the other processes rejected, they rebuilt the
   shared cache, plasmashell saw the file change, rejected their header, and rebuilt again. Measured
   at ~20 rebuilds in 40 s, all in-process, hence the CPU.

Because the rebuild happens inside `plasmashell` itself, it burns CPU without any child process
being visible, and it stops entirely as soon as nothing asks KService anything - which is why the
classic window list (`windowlist`, no KService queries) appeared to be "the good applet" while
Kickoff and both task managers appeared to be "the bad ones". They were the victims.

Confirmation test: point `XDG_CACHE_HOME` at a private tmpfs directory for a hand-started
plasmashell. The loop disappears (one rebuild, cache mtime frozen, 0.0 % CPU), because the two
environments no longer share a cache file.

### The correct start command

```sh
systemctl --user start plasma-plasmashell.service
```

The unit is `enabled` and is pulled in by `plasma-workspace.target`, so a normal login start is
enough. Do not `pkill plasmashell` and relaunch it with `setsid`; that is the bug.

### Diagnosing it

```sh
# Is the cache being rewritten? Run twice, 30 s apart; the mtime must not move.
stat -c '%y %i' ~/.cache/ksycoca6_*

# Which process is rebuilding, and why?
QT_LOGGING_RULES='kf.service.*=true;kf.coreaddons.kdirwatch=true' plasmashell >/tmp/pl.log 2>&1
grep -E 'Recreating ksycoca|timestamp changed|notifyDatabaseChanged' /tmp/pl.log

# Environment comparison across session processes
tr '\0' '\n' < /proc/$(pgrep -x plasmashell)/environ | grep -E 'XDG_CURRENT_DESKTOP|XDG_MENU_PREFIX'
```

A healthy system rebuilds once after a package install and otherwise never.

## Panel layout

Left to right, Windows-style:

```text
[ Kickoff ] [ task icons ........ ] [ -- spacer -- ] [ tray | battery % ] [ clock ]
```

`AppletOrder` in `~/.config/plasma-org.kde.plasma.desktop-appletsrc`:
`kickoff; icontasks; marginsseparator; systemtray; battery; digitalclock`. `marginsseparator` is the
expanding spacer that pushes the tray, battery and clock to the right end.

Two practical rules, learned the hard way:

- **Edit the file only with plasmashell stopped.** Plasma rewrites `appletsrc` on exit, so edits made
  while it runs are silently lost, or worse, merge into a corrupt state.
- **Prefer `systemctl --user restart plasma-plasmashell.service`** to `pkill`. A panel that has lost
  its system tray applet (missing volume/network icons) is the usual symptom of hand-editing while
  running; re-add it with `out/remote/fix-tray-and-measure.sh`.

## Stick as mouse

There is no touchpad. The pointer is a profile InputPlumber loads on demand:
`duo-mouse-apply` reads `/etc/duo/mouse-mode` and
`~/.config/duo/mouse-stick`, then calls `LoadProfilePath` on the composite
device over D-Bus with `mouse-left.yaml` or `mouse-right.yaml`. On this device
the choice is `left`: the left stick moves the pointer, the right stick scrolls.

That profile lives **inside the running daemon**, so `systemctl restart
inputplumber` silently removes it - the pointer stops working until the profile
is loaded again. `duo-mouse.service` now carries `PartOf=inputplumber.service`,
and `toolkit/cross/deploy.sh` restarts `duo-mouse` after a deploy, so the mapping
comes back by itself. If the pointer ever dies after an InputPlumber change:

```sh
systemctl restart duo-mouse
busctl call org.shadowblip.InputPlumber \
  /org/shadowblip/InputPlumber/CompositeDevice0 \
  org.freedesktop.DBus.Properties Get ss org.shadowblip.Input.CompositeDevice ProfilePath
```

The second command should print `mouse-left.yaml` rather than an empty string.

## Window placement across the two panels

KWin decides where a new window goes from `kwinrc [Windows] Placement`; with `ActiveMouseScreen=true`
the "active" screen follows the pointer. This machine now uses:

```ini
[Windows]
Placement=UnderMouse      # new windows appear on the screen under the pointer
ActiveMouseScreen=true
```

Since the pointer is the left stick in mouse mode, aiming at the bottom panel and launching an app
puts it there. The previous value was `Maximizing`, which let KWin pick the active screen and made
the result feel arbitrary.

Moving an existing window is KWin's `Window to Next Screen` / `Window to Previous Screen` global
shortcut (`Meta+Shift+Right` / `Meta+Shift+Left`), or `Window to Screen 0/1/2` (unbound by default;
on this machine `DSI-1` is screen 0 and `DP-1` is screen 1). Per-application overrides are KWin
**Window Rules** with a `Screen` property.

Because there is no physical keyboard, the two buttons that would otherwise be unused are mapped to
it in the InputPlumber profile (`/etc/inputplumber/profiles/mouse-left.yaml`):

| Button | Profile mapping | Action |
|---|---|---|
| **Start** | `Start` → `KeyF14` | send the focused window to the other panel (toggles back and forth) |
| **Select** | `Select` → `KeyF15` | close the focused window |

`duo-backkey` watches the InputPlumber keyboard node for F14/F15 and invokes
`org.kde.kglobalaccel /component/kwin invokeShortcut "Window to Previous Screen"` / `"Window Close"`
over D-Bus, so KWin still owns placement and closing. In *gamepad mode* both buttons still pass
through to games, because the generator only emits these actions into the mouse profiles.


## Battery indicator

One indicator only: **Plasma's own tray battery**. The standalone
`org.kde.plasma.battery` applet was removed (`out/remote/drop-panel-battery.py`), because it produced
a second battery readout next to the tray's.

What to expect from the stock tray item: it shows the battery icon in the panel, with the percentage
in its popup/tooltip. It does *not* render the number in the compact panel form, even with
`showPercentage=true` - that setting only affects the popup. The `hiddenItems` key did not hide it
either, so it was dropped rather than left as misleading configuration.

The trade-off, stated plainly: the panel no longer shows a percentage. The alternative was a
standalone applet showing icon + percentage, at the cost of a duplicate indicator. The default KDE
tray was chosen.

## Idle CPU budget

Measured on the Lite with two panels lit and nothing running:

| Process | Idle CPU | Notes |
|---|---|---|
| `inputplumber` | ~6 % (was 11 %) | sources now back off when idle (patch 0002); what remains is the target poll loop: ds5 4 ms, keyboard 8 ms, mouse 16 ms ≈ 437 wakeups/s. Dropping the ds5 target (`inputplumber device 0 targets set keyboard mouse`) removes ~250 of them if no game needs a virtual gamepad. |
| `duo-backkey` | 0.3 % | was 2.5 % with a fixed 5 ms tick; the tick is now 250 ms unless a stick is being integrated into scroll |
| `duo-fan` | 1 % | 2 s poll of the hwmon sensors |
| `plasmashell` | 0.1 % | with stock Kickoff + Icons-only Task Manager |
| `kwin_wayland` | 0.1 % | |

Overall the machine sits at ~93-95 % idle, with the little cluster at 300 MHz and the big cluster
parked at its minimum when nothing polls. `schedutil` is the governor, `boost=0`, and both policies
have `min=300 MHz`.

The one remaining large item is InputPlumber. Reducing it means patching the source poll loop (4-8 ms
instead of 1 ms) and rebuilding, which is a deliberate trade of input latency for battery; it is not
a configuration change.

## Scripts

- `out/remote/restore-stock-panel.py` - restore Kickoff + Icons-only Task Manager, dedupe, order.
- `out/remote/apply-stock-panel.sh` - the whole restore + verification pass.
- `out/remote/repair-panel.py` - repair applet sections merged by hand-editing (missing tray).
- `out/remote/repair-and-verify.sh` - stop, repair, restart, verify tray and CPU.
- `out/remote/drop-panel-battery.py` - remove the duplicate battery applet, keep the tray one.
- `out/remote/diag-sycoca.sh` - reproduce the rebuild storm and name the cause.
- `out/remote/fix-tray-and-measure.sh` - re-add the tray, order the panel, measure idle CPU.

## What a broken applet section looks like

Plasma stores each applet as a base section plus configuration groups:

```ini
[Containments][3][Applets][8]
immutability=1
plugin=org.kde.plasma.systemtray

[Containments][3][Applets][8][Configuration]
PreloadWeight=65
SystrayContainmentId=9

[Containments][3][Applets][8][Configuration][General]
hiddenItems=org.kde.plasma.battery
```

If `plugin=` ends up under `[Configuration][General]` and the base section is gone, the applet is
not instantiated at all - it simply vanishes from the panel at the next start, with no error in the
journal. A missing system tray (no volume or network icons) is the usual symptom. `repair-panel.py`
moves the keys back and keeps the tray whose inner containment actually holds items.


## Version policy (why we stay on trixie's 6.3.6)

KDE support said 6.3 is old and pointed at 6.6 as the current LTS. Both are true,
but there is no Debian route to 6.6: trixie ships 6.3.6, and testing/sid ship
Plasma 6.7.4 with Qt 6.11 and KF6 6.30. Debian does not backport Plasma, because a
backport would have to carry Qt and KF6 with it.

Decision: stay on trixie and move when the next stable release lands (forky
freezes around early 2027, releases around mid 2027). At that point the upgrade
is one coherent suite change that also brings a Plasma newer than 6.6 LTS.

Rejected, for the record:

- **Pinning the KDE/Qt stack from forky onto trixie.** Plasma 6.7 needs the newer
  Qt, which is built against forky's glibc, libstdc++, ICU, Mesa and libdrm. Apt
  then either pulls half of forky in or refuses, and every later trixie security
  update can conflict. Verified state: trixie 6.3.6 / Qt 6.8.2 / KF6 6.13.0 vs
  forky 6.7.4 / Qt 6.11.2 / KF6 6.30.0.
- **Building Plasma 6.6 from source.** Would need Qt 6.9+ plus roughly 80 KF6 and
  Plasma repositories maintained by hand.

## Keyboard-colour LED (Kameleon)

Kameleon lists the PMIC charger LED gb:status (/sys/class/leds/rgb:status, a
pwm LED on 1c40000.spmi:pmic@3:pwm) as a keyboard. It is cosmetic and belongs
to Kameleon, not to Plasma or the kernel; tracked upstream and left alone rather
than patched locally. The only LEDs on the system are mmc0, mmc1 and
gb:status.


## Screen layout and scaling (exact scales only)

Both panels use scale **1.6**, which divides both native resolutions exactly, so
no client has to live with fractional logical geometry:

| Output | Native | Scale | Logical | Position |
|---|---|---|---|---|
| DSI-1 (top, rotated) | 1920x1080 | 1.6 | 1200x675 | 0,0 |
| DP-1 (bottom) | 1280x960 | 1.6 | 800x600 | 0,675 |

Why it matters: at 1.75 the bottom screen was 731.43 logical px wide, so a
layer-shell surface could never sit flush and wvkbd showed a hairline of
background at the bottom/right edges. At 1.6 the keyboard is flush.

The position matters too. After changing the top scale its logical height became
675, so DP-1 had to move from y=618 to y=675; otherwise the screens overlap by
57 px and the top panel draws into the bottom display.

    kscreen-doctor output.DSI-1.scale.1.6
    kscreen-doctor output.DP-1.scale.1.6
    kscreen-doctor output.DP-1.position.0,675

## A taskbar on both screens

Plasma 6.3 has no "duplicate panel" button, so the second panel is created with
the scripting API, copying the first panel's applets in order
(`marginsseparator, digitalclock, icontasks, kickoff, systemtray`) at the same
height and alignment. `toolkit/apps/add-second-taskbar.sh` does this and is
idempotent: it refuses to add a second panel to a screen that already has one.
