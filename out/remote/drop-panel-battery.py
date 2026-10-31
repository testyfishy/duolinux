#!/usr/bin/env python3
"""Remove the standalone battery applet; keep Plama's own tray battery.

Run with plasmashell stopped. The tray item stays (it is the default KDE
indicator); the hiddenItems entry that was supposed to hide it evidently has no
effect, so it is removed rather than left as misleading configuration.
"""
import pathlib
import re

PATH = pathlib.Path("/home/duo/.config/plasma-org.kde.plasma.desktop-appletsrc")
CONTAINMENT = 3
text = PATH.read_text()

removed = []
for aid in re.findall(
    rf"\[Containments\]\[{CONTAINMENT}\]\[Applets\]\[(\d+)\]\n((?:(?!\[).*\n)*)", text
):
    pass

# Delete every battery applet that belongs to the panel itself (not the tray's).
for m in list(re.finditer(
    rf"\[Containments\]\[{CONTAINMENT}\]\[Applets\]\[(\d+)\]\n((?:(?!\[).*\n)*)", text
)):
    if m.group(2).find("plugin=org.kde.plasma.battery") == -1:
        continue
    aid = m.group(1)
    out, skip = [], False
    for line in text.splitlines():
        if line.startswith("["):
            skip = line.startswith((
                f"[Containments][{CONTAINMENT}][Applets][{aid}]",
                f"[Containments][{CONTAINMENT}][Applets][{aid}][",
            ))
        if not skip:
            out.append(line)
    text = "\n".join(out)
    removed.append(aid)

# The hiddenItems key had no visible effect; drop it so the config states the truth.
text = re.sub(r"\nhiddenItems=[^\n]*", "", text)

# Rebuild AppletOrder from what is actually left.
ids = [m.group(1) for m in re.finditer(
    rf"\[Containments\]\[{CONTAINMENT}\]\[Applets\]\[(\d+)\]\n", text
)]
order = [i for i in ids if i not in removed]
previous = re.search(r"AppletOrder=([0-9;]*)", text)
if previous:
    wanted = [i for i in previous.group(1).split(";") if i and i not in removed]
    order = wanted + [i for i in order if i not in wanted]
text = re.sub(r"AppletOrder=[0-9;]*", "AppletOrder=" + ";".join(order), text, count=1)

PATH.write_text(text.rstrip("\n") + "\n")
print("removed panel battery applets:", removed or "none")
print("AppletOrder =", ";".join(order))
