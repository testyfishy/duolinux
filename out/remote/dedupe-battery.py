#!/usr/bin/env python3
"""Leave exactly one battery indicator: the panel applet that shows a percentage.

Repeated addWidget calls during the CPU investigation left several copies, and
Plasma's system tray also carries its own. Remove every battery applet from the
panel except the first, and hide the tray's item.
"""
import pathlib
import re

PATH = pathlib.Path("/home/duo/.config/plasma-org.kde.plasma.desktop-appletsrc")
text = PATH.read_text()

# Every battery applet in the main panel containment.
ids = re.findall(
    r"\[Containments\]\[3\]\[Applets\]\[(\d+)\]\n[^\[]*?plugin=org\.kde\.plasma\.battery\n",
    text)
ids = list(dict.fromkeys(ids))
print("battery applets found:", ids)

keep = ids[0] if ids else None
for aid in ids[1:]:
    lines, out, skip = text.splitlines(), [], False
    for line in lines:
        if line.startswith("["):
            skip = (line == f"[Containments][3][Applets][{aid}]"
                    or line.startswith(f"[Containments][3][Applets][{aid}]["))
            if skip:
                continue
        if not skip:
            out.append(line)
    text = "\n".join(out)
    text = re.sub(r"(AppletOrder=[0-9;]*)\b" + aid + r";?", r"\1", text)
    text = text.replace(";;", ";")
    print(f"removed battery applet {aid}")

# Make sure the survivor shows the percentage.
if keep:
    marker = f"[Containments][3][Applets][{keep}][Configuration][General]"
    if marker in text:
        if "showPercentage" in text.split(marker, 1)[1].split("[", 1)[0]:
            text = re.sub(r"(?<=\n)showPercentage=(?:true|false)",
                          "showPercentage=true",
                          text.split(marker, 1)[0] + marker +
                          text.split(marker, 1)[1], count=1)
        else:
            text = text.replace(marker + "\n", marker + "\nshowPercentage=true\n", 1)
    else:
        text = text.replace(f"[Containments][3][Applets][{keep}]\n",
                            f"[Containments][3][Applets][{keep}]\n"
                            f"[Containments][3][Applets][{keep}][Configuration]\n"
                            f"[Containments][3][Applets][{keep}][Configuration][General]\n"
                            f"showPercentage=true\n", 1)

# Hide the system tray's battery item.
if "hiddenItems=" not in text:
    text = re.sub(r"(\[Containments\]\[3\]\[Applets\]\[\d+\]\[Configuration\]\[General\]\n)",
                  r"\1hiddenItems=org.kde.plasma.battery\n", text, count=1)
else:
    text = re.sub(r"hiddenItems=([^\n]*)",
                  lambda m: "hiddenItems=" + (
                      m.group(1) if "org.kde.plasma.battery" in m.group(1)
                      else (m.group(1) + ",org.kde.plasma.battery").lstrip(",")),
                  text)

PATH.write_text(text + "\n")
print("done")
