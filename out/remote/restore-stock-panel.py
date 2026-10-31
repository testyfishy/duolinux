#!/usr/bin/env python3
"""Restore the default Plasma panel applets, in a Windows-style order.

Run with plasmashell stopped (systemctl --user stop plasma-plasmashell.service),
because Plasma rewrites this file on exit.

What it does:
  * converts the fuzzel quicklaunch into org.kde.plasma.kickoff, in place
  * converts the classic window list into org.kde.plasma.icontasks, in place
  * deletes any other kickoff/task applet (duplicates from earlier edits)
  * orders the panel: launcher, task icons, expanding spacer, tray,
    battery percentage, clock at the far right end
  * keeps exactly one battery indicator, showing a percentage
"""
import pathlib
import re
import sys

PATH = pathlib.Path("/home/duo/.config/plasma-org.kde.plasma.desktop-appletsrc")
CONTAINMENT = 3
ORDER = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.icontasks",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.battery",
    "org.kde.plasma.digitalclock",
]
# Applets that are only ever wanted once; extras are deleted.
UNIQUE = {
    "org.kde.plasma.kickoff",
    "org.kde.plasma.icontasks",
    "org.kde.plasma.windowlist",
    "org.kde.plasma.quicklaunch",
    "org.kde.plasma.taskmanager",
}

text = PATH.read_text()


def applets(text: str) -> dict[str, str]:
    """Map applet id -> plugin inside the panel containment."""
    found = {}
    for match in re.finditer(
        rf"\[Containments\]\[{CONTAINMENT}\]\[Applets\]\[(\d+)\]\n((?:(?!\[).*\n)*)", text
    ):
        plugin = re.search(r"plugin=([\w.]+)", match.group(2))
        if plugin:
            found[match.group(1)] = plugin.group(1)
    return found


def drop_applet(text: str, aid: str) -> str:
    """Delete an applet and all of its configuration sections."""
    out, skip = [], False
    for line in text.splitlines():
        if line.startswith("["):
            skip = line.startswith(
                (f"[Containments][{CONTAINMENT}][Applets][{aid}]",
                 f"[Containments][{CONTAINMENT}][Applets][{aid}][")
            )
        if not skip:
            out.append(line)
    return "\n".join(out)


def set_plugin(text: str, aid: str, old: str, new: str) -> str:
    return re.sub(
        rf"(\[Containments\]\[{CONTAINMENT}\]\[Applets\]\[{aid}\]\n"
        rf"(?:(?!\[).*\n)*?plugin=){re.escape(old)}",
        lambda m: m.group(1) + new,
        text,
        count=1,
    )


# 1. Swap the substitutes back to stock applets, in place.
swapped = {}
for aid, plugin in applets(text).items():
    if plugin == "org.kde.plasma.quicklaunch":
        text = set_plugin(text, aid, plugin, "org.kde.plasma.kickoff")
        swapped["kickoff"] = aid
        print(f"{aid}: quicklaunch -> kickoff")
    elif plugin in ("org.kde.plasma.windowlist", "org.kde.plasma.taskmanager"):
        text = set_plugin(text, aid, plugin, "org.kde.plasma.icontasks")
        swapped["icontasks"] = aid
        print(f"{aid}: {plugin} -> icontasks")

if not swapped:
    print("no substitute applets found; nothing swapped", file=sys.stderr)

# 2. Delete duplicates (e.g. a kickoff added while diagnosing).
known = applets(text)
for aid, plugin in sorted(known.items(), key=lambda kv: int(kv[0])):
    if plugin not in UNIQUE:
        continue
    keep = swapped.get({"org.kde.plasma.kickoff": "kickoff",
                        "org.kde.plasma.icontasks": "icontasks"}.get(plugin, ""))
    if keep is None or aid == keep:
        continue
    text = drop_applet(text, aid)
    print(f"{aid}: removed duplicate {plugin}")

# 3. Order the panel.
known = applets(text)
by_plugin = {}
for aid, plugin in known.items():
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

# 4. One battery indicator, with a percentage.
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
print("AppletOrder =", order)
