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

## Battery indicator

One indicator only: the standalone `org.kde.plasma.battery` applet on the panel with
`showPercentage=true`, and `org.kde.plasma.battery` in the system tray's `hiddenItems`.

The tray's own copy cannot be used instead: in its compact panel form it shows the icon only, with
the percentage in the popup. It is the same plugin, but only the standalone applet renders the
number in the panel.

## Scripts

- `out/remote/restore-stock-panel.py` - restore Kickoff + Icons-only Task Manager, dedupe, order.
- `out/remote/apply-stock-panel.sh` - the whole restore + verification pass.
- `out/remote/diag-sycoca.sh` - reproduce the rebuild storm and name the cause.
- `out/remote/fix-tray-and-measure.sh` - re-add the tray, order the panel, measure idle CPU.
