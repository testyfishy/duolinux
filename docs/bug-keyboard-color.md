# Upstream report: Kameleon treats the PMIC charger LED as a keyboard

**Filed:** https://bugs.kde.org/show_bug.cgi?id=528087 (2026-10-31)

**Product:** plasmashell
**Component:** Brightness and Color widget
**Version:** 6.3.6 (Debian 13, `powerdevil 4:6.3.6-1`, `kdeplasma-addons`)

## Summary

Kameleon picks up `/sys/class/leds/rgb:status` — the PMIC charger status LED — as a keyboard RGB
LED. Consequences: the Brightness/Colour applet shows a "Keyboard Color" row on hardware with no
keyboard backlight, and the accent colour is written to the charger LED.

## Evidence

```
$ busctl --user call org.kde.kded6 /modules/kameleon org.kde.kameleon isSupported
b true

$ journalctl --user -b | grep -i kameleon
org.kde.kameleon: found RGB LED device "rgb:status"
org.kde.kameleon: wrote color "#3daee9" to LED devices

$ ls /sys/class/leds/
mmc0::  mmc1::  rgb:status
$ cat /sys/class/leds/rgb:status/multi_index
red green blue
```

`rgb:status` belongs to the PMIC (`/sys/class/leds` symlink under
`1c40000.spmi:pmic@3:pwm/leds/rgb:status`), not to a keyboard. There is no `*::kbd_backlight`
device on this machine.

## Cause

`kdeds/kameleon/kameleon.cpp`, `findRgbLedDevices()`: any device under `/sys/class/leds` whose
`multi_index` is `red green blue` is accepted as a keyboard LED. Nothing checks that the device is
actually a keyboard (for example a `kbd_backlight` name match). `DeviceLedsAccentColored` defaults to
true, so the accent colour is then written to the charger LED.

`KeyboardColorControl` (`powerdevil/applets/brightness/plugin/keyboardcolorcontrol.cpp`) sets
`supported` once from `org.kde.kameleon.isSupported`, and `KeyboardColorItem.qml` shows the row when
that is true — so the applet is behaving correctly given Kameleon's answer.

## Expected

Kameleon should only treat keyboard backlight LEDs as keyboard colour devices; the "Keyboard Color"
row should not appear, and the charger LED should not be recoloured.

## Suggested fix

Restrict `findRgbLedDevices()` to keyboard LEDs (e.g. require `kbd_backlight` in the device name),
or add a whitelist/blacklist for known non-keyboard LEDs.

## Environment

Debian 13 arm64, Plasma 6.3.6 Wayland, Qualcomm SM6125 handheld (Retroid Pocket Duo Lite), two
internal panels, on-screen keyboard only, no keyboard backlight.

Possibly related: bug 525995, bug 522894.
