#!/usr/bin/env python3
"""Repair the panel applet sections in appletsrc.

Earlier hand-editing merged applet base sections into their [Configuration][General]
blocks, so lines like `plugin=org.kde.plasma.systemtray` ended up in the wrong
place. Plasma cannot instantiate an applet without its base section and quietly
drops it at startup - which is why the system tray (volume, network) disappeared.

Run with plasmashell stopped:

    systemctl --user stop plasma-plasmashell.service
    python3 repair-panel.py
    systemctl --user start plasma-plasmashell.service

What it does:
  * moves stray plugin=/immutability= lines back into a real base section
  * keeps a single system tray, preferring the one whose inner containment exists
  * hides the tray's battery item (the panel applet shows the percentage)
  * sets the Kickoff icon to one this image actually ships
  * orders the panel Windows-style
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
KICKOFF_ICON = "view-app-grid-symbolic"
BASE_KEYS = ("plugin=", "immutability=")

raw = PATH.read_text()

# ---- split into sections -------------------------------------------------
sections: list[list] = []  # [header, [body lines]]
for line in raw.splitlines():
    if line.startswith("["):
        sections.append([line, []])
    elif sections:
        sections[-1][1].append(line)
    else:
        sections.append(["", [line]])

APP = re.compile(rf"^\[Containments\]\[{CONTAINMENT}\]\[Applets\]\[(\d+)\](?:\[(.+)\])?$")
CONT = re.compile(r"^\[Containments\]\[(\d+)\]$")


def applet_id(header: str):
    m = APP.match(header)
    return m.group(1) if m else None


def sub_group(header: str):
    m = APP.match(header)
    return m.group(2) if m else None


# ---- 1. pull stray base keys out of [Configuration][General] --------------
pending: dict[str, list[str]] = {}
for header, body in sections:
    if sub_group(header) != "Configuration][General":
        continue
    aid = applet_id(header)
    stray = [l for l in body if l.strip().startswith(BASE_KEYS)]
    if not stray:
        continue
    pending.setdefault(aid, []).extend(stray)
    body[:] = [l for l in body if not l.strip().startswith(BASE_KEYS)]
    print(f"applet {aid}: recovered {', '.join(s.split('=')[0] for s in stray)}")

# ---- 2. create missing base sections, just before the applet's first block -
have_base = {applet_id(h) for h, _ in sections if applet_id(h) and sub_group(h) is None}
for aid, stray in pending.items():
    if aid in have_base:
        continue
    insert_at = next(i for i, (h, _) in enumerate(sections) if applet_id(h) == aid)
    sections.insert(insert_at, [f"[Containments][{CONTAINMENT}][Applets][{aid}]", stray + [""]])
    print(f"applet {aid}: created base section")

# ---- 3. read back the applet table ---------------------------------------
plugins: dict[str, str] = {}
systray_containment: dict[str, str] = {}
for header, body in sections:
    aid = applet_id(header)
    if not aid:
        continue
    if sub_group(header) is None:
        for line in body:
            if line.strip().startswith("plugin="):
                plugins[aid] = line.split("=", 1)[1].strip()
    elif sub_group(header) == "Configuration":
        for line in body:
            if line.strip().startswith("SystrayContainmentId="):
                systray_containment[aid] = line.split("=", 1)[1].strip()

existing_containments = {m.group(1) for h, _ in sections if (m := CONT.match(h))}

# How many items live in each containment: an empty inner containment means an
# empty tray, so prefer the one that already holds the volume/network icons.
items_per_containment: dict[str, int] = {}
for header, _ in sections:
    m = re.match(rf"^\[Containments\]\[(\d+)\]\[Applets\]\[\d+\]$", header)
    if m:
        items_per_containment[m.group(1)] = items_per_containment.get(m.group(1), 0) + 1

# ---- 4. keep one usable system tray --------------------------------------
trays = [aid for aid, plugin in plugins.items() if plugin == "org.kde.plasma.systemtray"]
usable = sorted(
    (a for a in trays if systray_containment.get(a) in existing_containments),
    key=lambda a: (-items_per_containment.get(systray_containment[a], 0), int(a)),
)
keep_tray = usable[0] if usable else (trays[0] if trays else None)
for aid in trays:
    if aid == keep_tray:
        continue
    sections = [s for s in sections if applet_id(s[0]) != aid]
    plugins.pop(aid, None)
    print(f"applet {aid}: removed unusable duplicate tray")
if keep_tray:
    print(f"tray applet: {keep_tray} (inner containment {systray_containment.get(keep_tray)})")
else:
    print("no system tray applet present; the panel will have no tray", file=sys.stderr)

# ---- 5. per-applet configuration -----------------------------------------
def ensure_group(aid: str, group: str) -> list[str]:
    header = f"[Containments][{CONTAINMENT}][Applets][{aid}][Configuration][{group}]"
    for h, body in sections:
        if h == header:
            return body
    body: list[str] = []
    insert_at = next(i for i, (h, _) in enumerate(sections) if applet_id(h) == aid)
    # after the applet's last section, so Configuration stays before General
    while insert_at + 1 < len(sections) and applet_id(sections[insert_at + 1][0]) == aid:
        insert_at += 1
    sections.insert(insert_at + 1, [header, body + [""]])
    return sections[insert_at + 1][1]


def set_key(body: list[str], key: str, value: str) -> None:
    prefix = key + "="
    for i, line in enumerate(body):
        if line.strip().startswith(prefix):
            body[i] = f"{key}={value}"
            return
    if body and body[-1].strip() == "":
        body.insert(len(body) - 1, f"{key}={value}")
    else:
        body.append(f"{key}={value}")


if keep_tray:
    set_key(ensure_group(keep_tray, "General"), "hiddenItems", "org.kde.plasma.battery")
for aid, plugin in plugins.items():
    if plugin == "org.kde.plasma.battery":
        set_key(ensure_group(aid, "General"), "showPercentage", "true")
    elif plugin == "org.kde.plasma.kickoff":
        set_key(ensure_group(aid, "General"), "icon", KICKOFF_ICON)

# ---- 6. order the panel --------------------------------------------------
by_plugin: dict[str, str] = {}
for aid, plugin in plugins.items():
    by_plugin.setdefault(plugin, aid)
missing = [p for p in ORDER if p not in by_plugin]
if missing:
    print("missing applets:", missing, file=sys.stderr)
order_ids = [by_plugin[p] for p in ORDER if p in by_plugin]
# keep anything unexpected at the end rather than dropping it
order_ids += [aid for aid in plugins if aid not in order_ids]
order = ";".join(order_ids)

for header, body in sections:
    if header == f"[Containments][{CONTAINMENT}][General]":
        set_key(body, "AppletOrder", order)
        break
else:
    print("panel [General] section not found", file=sys.stderr)

# ---- 7. write ------------------------------------------------------------
out = []
for header, body in sections:
    if header:
        out.append(header)
    out.extend(body)
PATH.write_text("\n".join(out).rstrip("\n") + "\n")
print("AppletOrder =", order)
