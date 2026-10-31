# Upstream report draft: Brightness applet shows "Keyboard Color" with no keyboard backlight

**Product:** plasma-workspace
**Component:** Brightness and Color applet (plasmoid `org.kde.plasma.brightness`)
**Version:** Plasma 6.3.6 (Debian 13, `plasma-workspace 4:6.3.6-2`, `powerdevil 4:6.3.6-1`)

## Summary

The Brightness/Colour popup shows the "Keyboard Color" row (toggle that follows the accent colour)
on a machine with no keyboard backlight and no RGB keyboard, even though PowerDevil reports the
capability as unsupported.

## Steps to reproduce

1. Use a machine with no keyboard backlight (`/sys/class/leds` contains no `*::kbd_backlight`), and
   with PowerDevil running.
2. Open the Brightness and Color applet.

## Actual behaviour

The "Keyboard Color" row is listed. Toggling it does nothing useful, as there is no hardware behind it.

## Expected behaviour

The row is hidden, because `KeyboardColorItem.qml` sets `visible: keyboardColorControl.supported`
and the control's own source of truth says unsupported.

## Evidence

PowerDevil's answers on the session bus (all false), while the row is still rendered:

```
$ busctl --user call org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement \
      org.kde.Solid.PowerManagement isActionSupported s KeyboardBrightnessControl
b false
$ ... KeyboardColorControl   -> b false
$ ... KeyboardBrightness     -> b false
$ ... KeyboardColor          -> b false
```

`dbus-monitor --session "interface=org.kde.Solid.PowerManagement"` during a plasmashell restart shows
the applet's control issuing:

```
member=isActionSupported
   string "KeyboardBrightnessControl"
```

and the strings in `libbrightnesscontrolplugin.so` confirm the only action ids it knows are
`KeyboardBrightnessControl` and `KeyboardColorControl`.

Hardware check — there is no keyboard backlight device:

```
$ ls /sys/class/leds/
mmc0::  mmc1::  rgb:status        # rgb:status is the PMIC charger LED, not a keyboard
```

`/sys/class/leds/rgb:status/multi_index` is `red green blue`.

## Notes

- `KeyboardColorItem.qml` line 26: `visible: keyboardColorControl.supported`.
- The standalone `org.kde.plasma.battery` applet has no such gate and works, so the plugin renders
  fine; only the visibility decision appears wrong.
- A plausible cause is the control defaulting `supported` to true when the capability query cannot be
  resolved (action-id mismatch: the applet asks `KeyboardBrightnessControl`/`KeyboardColorControl`,
  while `isActionSupported` is being answered for other names), with no later update to the property.
- The journal contains no `KeyboardColor`/QML warnings at startup (`grep -ci KeyboardColor` = 0), so
  the binding does not appear to fail at the QML level.

## Environment

- Debian 13 arm64, Plasma 6.3.6 Wayland, KWin, PowerDevil 6.3.6.
- Qualcomm SM6125 handheld, two internal panels (DSI-1, DP-1).
- No keyboard backlight; on-screen keyboard only.
