#!/usr/bin/env python3
"""Panel tidy-up in the Plasma config, with plasmashell stopped.

  * remove the system tray's battery applet entirely (hiddenItems was ignored)
  * drop the clock from the second screen's panel
  * stop the top clock showing America/Detroit (2 h ahead of the system's MDT)
"""
import pathlib
import re

PATH = pathlib.Path("/home/duo/.config/plasma-org.kde.plasma.desktop-appletsrc")
lines = PATH.read_text().splitlines()


def remove_sections(prefix: str) -> int:
    """Remove a [Section] and every child [Section][...] beneath it."""
    global lines
    out, skipping, removed = [], False, 0
    for line in lines:
        if line.startswith("["):
            skipping = line == prefix or line.startswith(prefix[:-1] + "][")
            if skipping:
                removed += 1
                continue
        if not skipping:
            out.append(line)
    lines = out
    return removed


def drop_from_list(key: str, value: str) -> None:
    global lines
    for i, line in enumerate(lines):
        if line.startswith(key + "="):
            items = [i for i in line.split("=", 1)[1].split(",") if i and i != value]
            lines[i] = key + "=" + ",".join(items)


removed_tray = remove_sections("[Containments][9][Applets][25]")
drop_from_list("extraItems", "org.kde.plasma.battery")
drop_from_list("knownItems", "org.kde.plasma.battery")

removed_clock = remove_sections("[Containments][27][Applets][29]")

text = "\n".join(lines) + "\n"
text = text.replace("AppletOrder=28;29", "AppletOrder=28")
text = text.replace("selectedTimeZones=America/Detroit,Local", "selectedTimeZones=Local")

PATH.write_text(text)
print(f"tray battery sections removed: {removed_tray}")
print(f"second-panel clock sections removed: {removed_clock}")
print("battery still known:", "org.kde.plasma.battery" in text.replace(
    "[Containments][3][Applets][24]", ""))
