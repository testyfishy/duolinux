# DuoLinux

A dual-screen Debian workstation for the **Retroid Pocket Duo Lite** (Qualcomm QCS6125 / SM6125).

This is not a gaming frontend. It is a small Linux computer for the top half of the device: SSH,
tmux, Tailscale, logs, and an LLM/GPU cockpit on the 1080p panel, with a launcher and touch keyboard
on the 960p panel.

```
┌──────────────────────────────────────────────┐
│  DUO  14:32   battery 87%   tailscale up     │
│  FLEET      server 12ms  GPU 78%  VRAM 21G   │
│  LLM        ollama llama3.1:70b  18 tok/s    │
│  LOCAL      CPU 12%  MEM 1.8/7.6G  TEMP 41C  │
├──────────────────────────────────────────────┤
│  [ Terminal ] [ SSH ] [ LLM ] [ Wi-Fi ]      │
│  [ Files    ] [ Keys] [ Power] [ Settings ]  │
└──────────────────────────────────────────────┘
```

## What this is built on

The Duo Lite is **SM6115 / SM6125**, not the Q-7790 in the flagship Duo. That is good news:
ROCKNIX has a mature Duo Lite port, including:

- the `sm6125-retroid-pocket-duo-lite.dtb`
- drivers/patches for both panels, the WL818S bridge, Himax and Focaltech touch, WCN3990 Wi-Fi,
  WCN3950 Bluetooth, Adreno 610, audio and the fan
- a signed **SM6115 ABL** that can boot Linux from microSD

DuoLinux uses that hardware enablement (kernel 7.2.0 + modules + firmware) as the board support
package, and replaces the userspace with Debian 13, Sway, and the `duodeck` cockpit. The kernel is
GPL-2.0; provenance and the source-build path are in [`docs/BUILD.md`](docs/BUILD.md).

**Buildable today.** Kernel/DTB/modules, initramfs, `boot.img`, GPT + FAT + ext4 SD image, the
dual-screen session and the install tooling are all here. The remaining unknown is one hardware
behaviour: whether the ROCKNIX bootloader loads our external initramfs (`rdinit=/duo-init`). The
non-destructive `fastboot boot` path avoids that question entirely.

Read [`docs/STATUS.md`](docs/STATUS.md) before flashing anything.

## What you get

| Piece | What it is |
|---|---|
| Kernel | ROCKNIX SM6115 7.2.0 `Image`, Duo Lite DTB, 274 modules |
| Firmware | WCN3990 Wi-Fi, WCN3950 BT, ADSP, Adreno 610 zap, UCM, from the same nightly |
| Rootfs | Debian 13 `trixie` arm64, minimal, systemd, Sway |
| Session | Two outputs, per-screen workspaces, touch + gamepad navigation |
| Cockpit | `duodeck`: fleet latency, Tailscale state, GPU/LLM activity, local health |
| Remote | OpenSSH client/server, mosh, tmux, Tailscale, sshfs |
| Image | GPT: `ROCKNIX` (FAT32) + `STORAGE` (ext4), plus Android `boot.img` |
| Bootloader | ROCKNIX `abl_signed-SM6115.elf`, with stock-ABL backup scripts |
| Tools | `duo` CLI: setup, fetch, kernel, rootfs, image, probe, boot, install, collect |

The FAT/ext4 labels deliberately match the ROCKNIX layout (`ROCKNIX` / `STORAGE`) so the ABL finds
the same structure it already knows.

## Quick start (Windows + WSL2)

```powershell
# 1. Check the machine and install the one-time build dependencies
.\duo.ps1 setup --native

# 2. Build everything (1.4 GB hardware base + Debian rootfs, ~30 min)
.\duo.ps1 build

# The built image is out/duolinux-duol.img.

# 3. Plug in the Duo Lite, enable USB debugging, collect a report
.\duo.ps1 probe

# 4. Try a one-shot boot WITHOUT flashing anything
.\duo.ps1 boot
```

## Install it

**With a card reader:**

```powershell
.\duo.ps1 install --disk 3 --yes
```

`--disk 3` is PhysicalDrive3. `duo install` lists removable disks, refuses the system disk, refuses
a card smaller than the image, and checks the size before writing. Use at least a 16 GB card.
Run PowerShell **as Administrator** for a raw disk write.

**Without a card reader (over USB):**

```powershell
.\duo.ps1 install --via-adb --with-abl
```

This compresses the image, pushes it plus the SD writer and the SM6115 ABL to
`/sdcard/Download/duolinux/`, and leaves two taps in Retroid's
Settings → Handheld Settings → Advanced → Run script as root:

1. `install_sd.sh` — finds the removable card, refuses anything under 16 GiB, streams the image.
2. `flash_abl.sh` — **backs up** `abl_a`/`abl_b`, then flashes the ROCKNIX SM6115 ABL.

Copy `abl_a.img` and `abl_b.img` off the device before relying on it. Android and internal storage
are otherwise untouched.

Then power off, hold **Volume Down** at power-on, set **Boot mode = Linux**, **Boot source = SD
Card**, and start. See [`docs/BOOT.md`](docs/BOOT.md).

## Why Debian

- Tailscale, OpenSSH, mosh, tmux, git, Python and Docker CLI are first-class and current.
- `apt` is boring, which is what a device you rely on should be.
- The heavy lifting (panels, touch, Wi-Fi, GPU) is kernel + firmware, already solved by the
  ROCKNIX board support.
- A small rootfs boots fine from a decent A2 microSD; 4 GB RAM is enough for terminals and SSH.

## What is deliberately not here

- EmulationStation, RetroArch, game launchers. This is a work machine.
- A custom compositor. Sway already speaks two outputs and layer-shell correctly.
- A custom kernel. We use the maintained ROCKNIX SM6115 tree until a source build is needed.

## Documentation

- [`docs/STATUS.md`](docs/STATUS.md) — verified vs. assumed, current blockers
- [`docs/HARDWARE.md`](docs/HARDWARE.md) — SoC, panels, touch, firmware, DTS map
- [`docs/BOOT.md`](docs/BOOT.md) — ABL, SD layout, recovery
- [`docs/BRINGUP.md`](docs/BRINGUP.md) — step-by-step first boot with checkpoints
- [`docs/DAILY.md`](docs/DAILY.md) — SSH, Tailscale, LLM cockpit, controls
- [`docs/WIRELESS.md`](docs/WIRELESS.md) — line-by-line Wi-Fi, USB and card-reader install
- [`docs/BUILD.md`](docs/BUILD.md) — pipeline, kernel provenance, source-build path
- [`docs/FIXES.md`](docs/FIXES.md) — upstream/community sweep and ABL status

## Safety

Flash the ABL only after the SD image boots via `fastboot boot`, and always keep the stock ABL
backup. This project refuses to write a disk it cannot identify as removable, and never touches
internal storage unless you run `flash_abl.sh` yourself.

## License

Tooling and overlay: MIT. Kernel: GPL-2.0 (ROCKNIX SM6115 tree). Firmware blobs remain the property
of their owners and are fetched from the public nightly at build time, not redistributed here.
