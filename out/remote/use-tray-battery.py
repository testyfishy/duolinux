#!/usr/bin/env python3
"""Use Plasma's own tray battery with a percentage; drop the standalone applet.

The tray item is the same org.kde.plasma.battery plugin, so it honours
showPercentage. Our panel applet is removed, and the tray's item is unhidden and
configured.
"""
import pathlib
import re

PATH = pathlib.Path("/home/duo/.config/plasma-org.kde.plasma.desktop-appletsrc")
text = PATH.read_text()

# 1. Remove the standalone battery applet(s) from the panel containment.
ids = list(dict.fromkeys(re.findall(
    r"\[Containments\]\[3\]\[Applets\]\[(\d+)\]\n[^\[]*?plugin=org\.kde\.plasma\.battery\n",
    text)))
for aid in ids:
    out, skip = [], False
    for line in text.splitlines():
        if line.startswith("["):
            skip = (line == f"[Containments][3][Applets][{aid}]"
                    or line.startswith(f"[Containments][3][Applets][{aid}]["))
            if skip:
                continue
        if not skip:
            out.append(line)
    text = "\n".join(out)
    text = re.sub(r"(AppletOrder=[0-9;]*)\b" + aid + r";?", r"\1", text).replace(";;", ";")
print("removed panel battery applets:", ids)

# 2. Unhide the tray's battery item.
def strip_battery(match: re.Match) -> str:
    items = [i for i in match.group(1).split(",") if i and i != "org.kde.plasma.battery"]
    return "hiddenItems=" + ",".join(items)

text = re.sub(r"hiddenItems=([^\n]*)", strip_battery, text)

# 3. Ensure the tray's battery applet exists and shows a percentage.
tray_ids = list(dict.fromkeys(re.findall(
    r"\[Containments\]\[9\]\[Applets\]\[(\d+)\]\n[^\[]*?plugin=org\.kde\.plasma\.battery\n",
    text)))
if tray_ids:
    aid = tray_ids[0]
    marker = f"[Containments][9][Applets][{aid}][Configuration][General]"
    if marker not in text:
        text = text.replace(
            f"[Containments][9][Applets][{aid}]\n",
            f"[Containments][9][Applets][{aid}]\n"
            f"[Containments][9][Applets][{aid}][Configuration]\n"
            f"[Containments][9][Applets][{aid}][Configuration][General]\n"
            f"showPercentage=true\n", 1)
    elif "showPercentage" not in text.split(marker, 1)[1].split("[", 1)[0]:
        text = text.replace(marker + "\n", marker + "\nshowPercentage=true\n", 1)
    print("tray battery applet:", aid)
else:
    print("tray battery applet missing; the tray will recreate it from knownItems")

PATH.write_text(text + "\n")
print("done")
