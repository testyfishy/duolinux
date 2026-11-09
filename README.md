# DuoLinux

Debian 13 (trixie) with a KDE Plasma 6.3 Wayland desktop on the **Retroid Pocket Duo Lite**
dual-screen handheld (Qualcomm SM6125, Adreno 610). Linux runs from the internal eMMC and boots
through a custom openABL; Android on internal storage is left intact as a 32 GiB userdata, and a
microSD card carries an independent rescue system.

The kernel is our own build, **7.2.11-nf**: ROCKNIX's 79-patch SM6115 device series rebased onto
the 7.2.11 stable tarball, with netfilter enabled so Tailscale runs in TUN mode. See
[`docs/KERNEL.md`](docs/KERNEL.md) for how it is ported and verified.

> **Hobby project, maintained in bursts.** It works as described below and is
> built for one device; I come back to it when time allows. Current state and
> known limits are in
> [`docs/STATE.md`](docs/STATE.md), and what would need help is in
> [`docs/HELP-WANTED.md`](docs/HELP-WANTED.md).
>
> **On hold as of 2026-11-01.** The device works and boots from the internal
> eMMC, but I have paused active work. Issues and PRs may sit for a while.

There is no physical keyboard. Input is the built-in gamepad (through
[InputPlumber](https://github.com/ShadowBlip/InputPlumber)) and two touchscreens, so most of this
repo is about making a normal desktop usable with those.

> The first pass of this project targeted a Sway "cockpit" session; `docs/` and the Python
> toolkit still describe that. The device now runs Plasma, and the scripts in `out/remote/` are
> what is actually deployed.

## Where it stands, and where I'd love help

This is a **fun project**. I love this little dual-screen handheld, and I want it
to be a genuinely good Linux machine rather than a proof of concept - every
feature in this repo runs on my own device, and the gaps below are the reason it
is public. If you know Qualcomm audio or video, any of these would be a real
gift.

| Area | State | What would settle it |
|---|---|---|
| **Microphone** | Powered and routed, but the LPASS DMIC clock is never enabled, so capture stays silent | the board's DMIC wiring, or a working mainline clock sequence |
| **Speaker level** | Works, but quieter than stock Android; both amps are already at their profile maximum | the ADSP calibration Android applies (`acdbdata`) |
| **Volume slider** | Does nothing: the card's `ELEM_INFO` is broken, so PipeWire cannot drive the amp | a fix for the ALSA control path |
| **Hardware video (Venus)** | Clock driver, DTS and DTB in place; decoder/encoder nodes register, but the core never powers up | the correct SM6125 `videocc` table and IOMMU stream IDs |

The measurements behind each row, and what has already been ruled out, are in
[`docs/HELP-WANTED.md`](docs/HELP-WANTED.md). What I have asked the vendor for is
in [`docs/OUTREACH.md`](docs/OUTREACH.md).

## Hardware at a glance

| Part | Details |
|---|---|
| SoC / GPU | Qualcomm SM6125 (SM6115 family), Adreno 610 |
| Top screen | `DSI-1`, 1080x1920@60 (rotated), scale 1.75 → 1098x618 logical |
| Bottom screen | `DP-1`, 1280x960@60, behind an Analogix DSI-to-DP bridge, scale 1.16667 → 1098x823 logical, placed below DSI-1 |
| Input | built-in gamepad (via InputPlumber), two touch panels, no keyboard |
| Boot | openABL from the ROCKNIX project; `KERNEL` is our 7.2.11-nf `Image.gz` on a FAT partition, DTB loaded from the same partition |
| Storage | Debian rootfs on the eMMC (70 GiB ext4, `LINUXROOT`); Android kept with a 32 GiB userdata; microSD is a self-contained rescue system |
| Kernel | 7.2.11-nf, 280 modules in `/lib/modules/7.2.11-nf`, `KERNEL.720nf` and `KERNEL.720` kept for rollback |

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
| `out/inputplumber-fork/` | Patch adding axis-to-wheel support to InputPlumber, plus publishing notes |
| `kernel/patches/7.2.11/` | The 79-patch SM6115 series rebased onto Linux 7.2.11, cleanly applicable in order, with the original authors preserved and a README covering how to carry it to a newer stable kernel |
| `toolkit/kernel/` | The kernel: port the SM6115 series to a new stable base, build it with netfilter, and every check used before and after installing (boot-critical built-ins, config diff, DTB compatibility, suspend, charging) |
| `docs/` | Bring-up notes: boot chain, hardware map, build pipeline, status ledger |
| `docs/KERNEL.md` | 7.2.11-nf: how the series is rebased, the one conflict and how it is resolved, how the port is proven, install and rollback |
| `docs/SUSPEND.md` | Who really suspends on lid close, why PowerDevil does not, and how to prove a suspend is real rather than a blanked display |
| `docs/EMMC.md` | Moving the rootfs to the eMMC beside a kept Android install |
| `docs/PLASMA.md` | Plasma session: why plasmashell must run as a user unit, panel layout, battery |
| `docs/TAILSCALE.md` | Tailscale: the netfilter requirement, what was missing on the stock kernel, and how it now runs in TUN mode |
| `docs/CPU-GPU.md` | CPU/GPU driver stack, Turnip, energy-model and cluster-idle gaps |
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
- **`duo-tailscale`**: a tray indicator for tailscaled. Tailscale's Linux package ships no GUI at
  all (only `tailscale` and `tailscaled`), so this is a small GTK/Ayatana indicator over the local
  CLI: state and Tailscale IP, log in (opens the auth URL), connect/disconnect, copy IP. It needs
  `tailscale set --operator=<user>` on the daemon and autostarts with the session.
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

## Verified on the hardware

| Area | Evidence |
|---|---|
| Boot from eMMC | Debian on `LINUXROOT`, 4K QD1 2,567 IOPS, 320 MiB/s sequential, 98 % idle |
| Both panels | `DSI-1` + `DP-1` connected, correct layout and scale, 3/3 blank/unblank cycles |
| Lid | close suspends (real sleep, 0 failures), open resumes, Wi-Fi drops and returns; idle never suspends |
| Power | battery gauge, charger hot-plug, JEITA path, charging at ~1.7 A |
| Kernel | 7.2.11-nf, 0 failed units, both remoteprocs running, audio card present |
| Netfilter | `nft`, `iptables`, `ip rule`; Tailscale runs in TUN mode (needs approval on first use) |

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
  `out/remote/`, `out/device-config/`): **GPLv3**, see [`LICENSE`](LICENSE). Copyright (C) 2026
  The DuoLinux authors. Use it, change it and share it; if you distribute a modified version,
  share its source under GPLv3 too. Versions before 2026-11-09 were published under MIT and stay MIT.
- **`kernel/patches/`** change the Linux kernel and stay **GPL-2.0**, like the kernel files they
  patch (see the SPDX line in each patch).
- **`out/wvkbd-0.15/`** is a modified copy of [wvkbd](https://git.sr.ht/~proycon/wvkbd),
  (c) 2020 John Sullivan and contributors, **GPLv3** (`LICENSE`, `COPYING`), with
  `os-compatibility.[ch]` under MIT/X (`COPYING_WESTON`). The changes are listed in
  `NOTICE.duolinux` and are themselves GPLv3. The commit history shows the unmodified upstream
  import followed by the patch.
- **`out/inputplumber-fork/`** is a patch against [InputPlumber](https://github.com/ShadowBlip/InputPlumber)
  v0.82.0, **GPLv3** like upstream. It is a patch file, not a redistribution of the source.
- Kernel, firmware, openABL and InputPlumber come from their upstream projects under their own
  licences and are not redistributed here.

If you redistribute the keyboard fork, keep its licence files and copyright notices intact.
