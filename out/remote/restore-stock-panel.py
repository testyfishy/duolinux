#!/usr/bin/env python3
"""Put stock Kickoff and the Icons-only Task Manager back on the panel.

Run with plasmashell stopped. The substitute applets are converted in place so
their ids (and therefore AppletOrder) stay valid:

  quicklaunch (fuzzel)  -> org.kde.plasma.kickoff
  windowlist           -> org.kde.plasma.icontasks

Layout stays Windows-style: launcher, task icons, expanding spacer, tray,
battery percentage, clock at the far right end.

Only apply this once the panel-loop root cause is fixed; on an unfixed system
icontasks will burn ~29 % of a core.
"""
import pathlib
import re
import sys

PATH = pathlib.Path("/home/duo/.config/plasma-org.kde.plasma.desktop-appletsrc")
text = PATH.read_text()

CONTAINMENT = 3
SWAPS = {
    "org.kde.plasma.quicklaunch": "org.kde.plasma.kickoff",
    "org.kde.plasma.windowlist": "org.kde.plasma.icontasks",
}
ORDER = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.icontasks",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.battery",
    "org.kde.plasma.digitalclock",
]

# Map applet id -> plugin for the panel containment.
applets: dict[str, str] = {}
pattern = re.compile(
    rf"\[Containments\]\[{CONTAINMENT}\]\[Applets\]\[(\d+)\]\n((?:(?!\[).*\n)*)"
)
for match in pattern.finditer(text):
    plugin = re.search(r"plugin=([\w.]+)", match.group(2))
    if plugin:
        applets[match.group(1)] = plugin.group(1)

changed = []
for aid, plugin in applets.items():
    if plugin in SWAPS:
        new = SWAPS[plugin]
        text = re.sub(
            rf"(\[Containments\]\[{CONTAINMENT}\]\[Applets\]\[{aid}\]\n"
            rf"(?:(?!\[).*\n)*?plugin=){re.escape(plugin)}",
            lambda m: m.group(1) + new,
            text,
            count=1,
        )
        changed.append(f"{aid}: {plugin} -> {new}")

if not changed:
    print("nothing to swap; check the applet ids", file=sys.stderr)

# Rebuild the id -> plugin map after the swap, then set AppletOrder.
applets = {}
for match in pattern.finditer(text):
    plugin = re.search(r"plugin=([\w.]+)", match.group(2))
    if plugin:
        applets[match.group(1)] = plugin.group(1)
by_plugin = {}
for aid, plugin in applets.items():
    by_plugin.setdefault(plugin, aid)

missing = [p for p in ORDER if p not in by_plugin]
if missing:
    print("missing applets:", missing, file=sys.stderr)

order = ";".join(by_plugin[p] for p in ORDER if p in by_plugin)
if "AppletOrder=" in text:
    text = re.sub(r"AppletOrder=[0-9;]*", f"AppletOrder={order}", text, count=1)
else:
    text = re.sub(
        rf"(\[Containments\]\[{CONTAINMENT}\]\[General\]\n)",
        r"\1AppletOrder=" + order + "\n",
        text,
        count=1,
    )

# Exactly one battery indicator: the panel applet keeps the percentage, the
# tray's copy stays hidden.
tray_id = by_plugin.get("org.kde.plasma.systemtray")
if tray_id:
    anchor = f"[Containments][{CONTAINMENT}][Applets][{tray_id}][Configuration][General]\n"
    text = re.sub(r"\nhiddenItems=[^\n]*", "", text, count=1)
    if anchor in text:
        text = text.replace(anchor, anchor + "hiddenItems=org.kde.plasma.battery\n", 1)
    else:
        text = text.replace(
            f"[Containments][{CONTAINMENT}][Applets][{tray_id}]\n",
            f"[Containments][{CONTAINMENT}][Applets][{tray_id}]\n"
            f"[Containments][{CONTAINMENT}][Applets][{tray_id}][Configuration]\n"
            f"[Containments][{CONTAINMENT}][Applets][{tray_id}][Configuration][General]\n"
            f"hiddenItems=org.kde.plasma.battery\n",
            1,
        )

battery_id = by_plugin.get("org.kde.plasma.battery")
if battery_id:
    marker = f"[Containments][{CONTAINMENT}][Applets][{battery_id}][Configuration][General]"
    if marker not in text:
        text = text.replace(
            f"[Containments][{CONTAINMENT}][Applets][{battery_id}]\n",
            f"[Containments][{CONTAINMENT}][Applets][{battery_id}]\n"
            f"[Containments][{CONTAINMENT}][Applets][{battery_id}][Configuration]\n"
            f"[Containments][{CONTAINMENT}][Applets][{battery_id}][Configuration][General]\n"
            f"showPercentage=true\n",
            1,
        )
    elif "showPercentage" not in text.split(marker, 1)[1].split("[", 1)[0]:
        text = text.replace(marker + "\n", marker + "\nshowPercentage=true\n", 1)

PATH.write_text(text + "\n")
for line in changed:
    print(line)
print("AppletOrder =", order)
