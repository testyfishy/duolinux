#!/usr/bin/env python3
"""Arrange the panel like a Windows taskbar.

Left to right: launcher, task icons, expanding spacer, tray, battery percentage,
clock at the far right end.

Run with plasmashell stopped: Plasma rewrites this file on exit, so edits made
while it runs can be lost.
"""
import pathlib
import re

PATH = pathlib.Path("/home/duo/.config/plasma-org.kde.plasma.desktop-appletsrc")
text = PATH.read_text()

ORDER = [
    "org.kde.plasma.quicklaunch",
    "org.kde.plasma.windowlist",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.systemtray",
    "org.kde.plasma.battery",
    "org.kde.plasma.digitalclock",
]

found: dict[str, str] = {}
for aid in re.findall(r"\[Containments\]\[3\]\[Applets\]\[(\d+)\]\n", text):
    block = text.split(f"[Containments][3][Applets][{aid}]", 1)[1].split("[", 1)[0]
    plugin = re.search(r"plugin=([\w.]+)", block)
    if plugin and plugin.group(1) not in found:
        found[plugin.group(1)] = aid

missing = [p for p in ORDER if p not in found]
if missing:
    print("missing applets:", missing)

order = ";".join(found[p] for p in ORDER if p in found)
if "AppletOrder=" in text:
    text = re.sub(r"AppletOrder=[0-9;]*", f"AppletOrder={order}", text, count=1)
else:
    text = re.sub(r"(\[Containments\]\[3\]\[General\]\n)",
                  r"\1AppletOrder=" + order + "\n", text, count=1)

# The battery applet must keep showing its percentage.
aid = found.get("org.kde.plasma.battery")
if aid:
    marker = f"[Containments][3][Applets][{aid}][Configuration][General]"
    if marker not in text:
        text = text.replace(
            f"[Containments][3][Applets][{aid}]\n",
            f"[Containments][3][Applets][{aid}]\n"
            f"[Containments][3][Applets][{aid}][Configuration]\n"
            f"[Containments][3][Applets][{aid}][Configuration][General]\n"
            f"showPercentage=true\n", 1)
    elif "showPercentage" not in text.split(marker, 1)[1].split("[", 1)[0]:
        text = text.replace(marker + "\n", marker + "\nshowPercentage=true\n", 1)

PATH.write_text(text + "\n")
print("AppletOrder =", order)
