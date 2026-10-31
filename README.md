# DuoLinux

Debian 13 (trixie) with a KDE Plasma 6.3 Wayland desktop on the **Retroid Pocket Duo Lite**
dual-screen handheld (Qualcomm SM6125, Adreno 610). Linux runs from a microSD card and boots
through a custom openABL; Android on internal storage is left intact.

There is no physical keyboard. Input is the built-in gamepad (through
[InputPlumber](https://github.com/ShadowBlip/InputPlumber)) and two touchscreens, so most of this
repo is about making a normal desktop usable with those.

> The first pass of this project targeted a Sway "cockpit" session; `docs/` and the Python
> toolkit still describe that. The device now runs Plasma, and the scripts in `out/remote/` are
> what is actually deployed.

## Hardware at a glance

| Part | Details |
|---|---|
| SoC / GPU | Qualcomm SM6125 (SM6115 family), Adreno 610 |
| Top screen | `DSI-1`, 1280x720 logical |
| Bottom screen | `DP-1`, 1280x960, behind an Analogix DSI-to-DP bridge, placed below DSI-1 |
| Input | built-in gamepad (via InputPlumber), two touch panels, no keyboard |
| Boot | openABL from the ROCKNIX project, kernel + DTB from the ROCKNIX SM6115 tree |
| Storage | Debian rootfs on microSD; Android untouched |

## What is in this repository

| Path | What it is |
|---|---|
| `toolkit/`, `duo`, `duo.ps1`, `Makefile` | Image tooling: fetch the kernel and firmware, build the Debian rootfs, `boot.img` and the GPT SD image, install helpers, the wvkbd patch script |
| `configs/`, `overlay/` | Rootfs package list, setup script and the original (Sway-era) overlay |
| `out/abl/`, `out/*.sh`, `out/patch/` | Android-side "run script as root" helpers (ABL backup/flash, SD writer, verification) and the in-place boot partition patcher |
| `out/remote/` | Scripts deployed to the running device: settings pages, daemons, install/fix scripts |
| `out/device-config/` | Snapshot of the live device configuration: `/etc/duo`, InputPlumber profiles, systemd units, udev and polkit rules, KWin/KDE settings, `duo-session`. This is what makes the setup reproducible rather than just the scripts |
| `out/overlay/` | USB-gadget networking, ssh self-heal and diagnostics units |
| `out/wvkbd-0.15/` | Forked on-screen keyboard (GPLv3), see below |
| `out/vboard-fork/` | Vboard fork, tried and rejected; kept for reference only (GPLv3) |
| `docs/` | Bring-up notes: boot chain, hardware map, build pipeline, status ledger |
| `tests/` | Unit tests for the image/boot.img builders |

Built images, the kernel, firmware, InputPlumber binaries, logs and SSH keys are **not** in the
repository (see `.gitignore`).

### Main features

- **On-screen keyboard**: a fork of wvkbd 0.15 with two patches:
  - `--output NAME` pins the layer-shell surface to a named output (e.g. `DP-1`);
  - a **uinput key backend**. KWin does not implement `zwp_virtual_keyboard_v1`, so stock wvkbd
    cannot type on Plasma at all; keys now go through a kernel uinput device.
- **Controller mapping**: InputPlumber device profiles (`gamepad.yaml`, `mouse-left.yaml`,
  `mouse-right.yaml`) are generated from `/etc/duo/controller.json` by `duo-controller-apply`.
  `duo-controller` is a GTK "Controller" settings page for remapping buttons by name.
- **`duo-backkey`** (user service): back button toggles the keyboard (it arrives as `KEY_F1` on
  InputPlumber's virtual keyboard), Home runs a configurable action, and the right stick becomes
  hi-res wheel scrolling (InputPlumber profiles cannot emit wheel events).
- **`duo-pad-node`**: recreates the physical gamepad's `/dev/input/event*` node, which InputPlumber
  hides from userspace.
- **`duo-fan`**: a fan-curve daemon modelled on lm-sensors `fancontrol` (averaging window,
  interpolated curve, hysteresis, dwell, MINSTART kick, MINSTOP floor, rate limiting) with
  quiet / balanced / performance profiles. It takes `pwm1` away from the kernel thermal governor.
- Display setup (`duo-display`, `duo-bottom-detect`), touch-to-output mapping (`duo-touch-map`,
  `plasma-touch-map.sh`), Wi-Fi picker (`duo-wifi`), status bar (`duo-status`), clock sync
  (`clock-unit.sh`, `clock2.sh`), mouse mode (`duo-mouse-*`), and OpenSSH over a USB gadget link as
  a rescue path (`out/overlay`, `duo-remote.ps1`, `deploy.ps1`).

## Hardware and firmware quirks

- **DP-1 needs a manual detect.** The bottom panel sits behind an Analogix bridge that does not
  report hotplug at boot. Run `echo detect > /sys/class/drm/card0-DP-1/status` (as root) before
  the compositor starts; `duo-bottom-detect` and the unit written by `early-detect-unit.sh` do this.
- **InputPlumber hides the physical pad.** To stop games seeing two controllers it removes the real
  gamepad's evdev node. The right stick is only readable there, so `duo-pad-node` recreates the node
  from sysfs (`mknod`, `root:input`, 0660).
- **KWin has no `zwp_virtual_keyboard_v1`.** Any Wayland OSK that relies on it (stock wvkbd,
  squeekboard-style tools) silently does nothing on Plasma; hence the uinput backend. The user
  needs write access to `/dev/uinput` (udev rule in `overlay/etc/udev/rules.d/99-duo-uinput.rules`).
- **Stick scaling differs per device.** The physical pad reports roughly **+/-850** on both sticks;
  InputPlumber's virtual DualSense reports **0..255 centred at 127** (8-bit). Thresholds and
  dead-zones must be computed from each device's `EVIOCGABS` range, not hard-coded.
- **The fan has two masters by default.** The kernel thermal governor also drives `pwm1`;
  `duo-fan` switches the relevant thermal zones away from it before taking over.

## Deploying to the device

The device is reached over the USB gadget link (`10.55.0.1`, PC side `10.55.0.2`; see
`out/remote/duo-remote.ps1` and `set-duo-link.ps1`) or over Wi-Fi. Use your own SSH key; none is
included here.

```powershell
# copy scripts to the device and install them
scp -i <your_key> out\remote\duo-* duo@10.55.0.1:/tmp/
ssh -i <your_key> duo@10.55.0.1 "sudo install -m 755 /tmp/duo-* /usr/local/bin/"
```

Most features have an `install-*.sh` script in `out/remote/` that writes the systemd unit and
config, for example:

| Feature | Installer | Unit |
|---|---|---|
| Fan control | `install-fan.sh`, `install-fan-settings.sh` | `duo-fan.service` (system) |
| Back key / scroll | `install-backkey.sh` | `duo-backkey.service` (user, `systemctl --user`) |
| Controller profiles | `install-controller-settings.sh`, `deploy-controller-v2.sh` | writes `/etc/duo/controller.json`, then `duo-controller-apply` |
| Bottom screen detect | `early-detect-unit.sh` | `duo-bottom-detect.service` |
| Clock | `clock-unit.sh`, `clock2.sh` | `duo-clock.service`, `duo-clock-save.timer` |
| USB link / ssh self-heal | `out/overlay/` | `duo-usb-gadget`, `duo-sshfix`, `duo-diag` |

Run installers as root on the device (`sudo bash install-fan.sh`). `deploy.ps1 push <tree>` pushes
a whole tree with a dead-man rollback timer. Many other scripts in `out/remote/` are one-off probes
and fixes kept as a record of the bring-up; read a script before running it.

Building the SD image itself is covered in `docs/BUILD.md` and `docs/BOOT.md`.

### Building the keyboard

```sh
cd out/wvkbd-0.15
make            # needs wayland, pango/cairo, xkbcommon dev packages
./wvkbd-mobintl --output DP-1 -L 300
```

## Settings surfaces

| Command | What it changes |
|---|---|
| `duo-settings` | fuzzel menu on DSI-1: scale, keyboard size, mouse speed, Wi-Fi, apps, power |
| `duo-controller` | Button remapping (GTK), writes `/etc/duo/controller.json`, scroll direction |
| `duo-fan-settings` | Fan profile (`/etc/duo/fan-profile`) |
| `duo-mouse-settings`, `duo-mouse-speed`, `duo-mouse-toggle` | Stick-as-mouse mode and speed |
| `duo-kbd-settings` | On-screen keyboard size |
| `duo-wifi` | Wi-Fi network picker |
| `duo-scale`, `duo-display` | Output scale and layout |

## Status and known limitations

- **Right-stick scrolling** is implemented in `duo-backkey` as hi-res wheel events, because
  InputPlumber 0.82 has no axis-to-wheel target. Speed, dead-zone and direction (natural or
  inverted) are tunable; a proper upstream wheel mapping is the cleaner long-term fix.
- **L2/R2 are unassigned** in the default controller map.
- **The button-mapping UI is minimal**: remap by name only, no live capture/preview, no per-app
  profiles.
- **Battery and audio applets came from packages the initial Plasma install skipped**
  (`powerdevil`, `plasma-pa`). Both are now part of the documented package set; without them the
  panel shows no battery and the tray reports a missing QML module.
- **No floating keyboard**: wvkbd is a docked layer-shell panel on one output; it cannot be moved
  or resized by touch.
- The Python toolkit and `docs/` still describe the Sway first pass; the Plasma setup is
  reproduced by the scripts in `out/remote/`, not by the image builder.
- The USB rescue shell (`duo-rescue-shell` and its clients) is **not** in this repository because it
  used a hard-coded token. Re-add it only with the token read from a file outside the repo.

## Licence

- **This project's own code** (toolkit, scripts, overlays, docs, the Duo Lite scripts in
  `out/remote/`, `out/device-config/`): **MIT**, see [`LICENSE`](LICENSE). Use it, change it,
  sell it, ship it — no permission needed.
- **`out/wvkbd-0.15/`** is a modified copy of [wvkbd](https://git.sr.ht/~proycon/wvkbd),
  (c) 2020 John Sullivan and contributors, **GPLv3** (`LICENSE`, `COPYING`), with
  `os-compatibility.[ch]` under MIT/X (`COPYING_WESTON`). The changes are listed in
  `NOTICE.duolinux` and are themselves GPLv3. The commit history shows the unmodified upstream
  import followed by the patch.
- **`out/vboard-fork/`** is a modified copy of [Vboard](https://github.com/mdev588/vboard),
  (c) 2025 mdev588, (c) 2026 Archisman Panigrahi, **GPLv3** (`LICENSE`, `NOTICE.duolinux`).
- Kernel, firmware, openABL and InputPlumber come from their upstream projects under their own
  licences and are not redistributed here.

If you redistribute the forks, keep their licence files and copyright notices intact.
