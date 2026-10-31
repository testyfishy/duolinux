# Bring-up — Duo Lite

Stop at the first failure and collect evidence before changing anything.

## 0. Build

```powershell
.\duo.ps1 setup --native      # one-time, asks for your WSL password
.\duo.ps1 build
```

Expected artifacts:

```
out/kernel/Image                                   ROCKNIX 7.2.0 arm64 Image
out/kernel/sm6125-retroid-pocket-duo-lite.dtb
out/kernel/modules/lib/modules/7.2.0/               274 modules
out/boot-duolinux-duol.img
out/duolinux-duol.img
out/SHA256SUMS
```

The hardware base download is ~1.4 GB. It is cached in `~/.cache/duolinux/rocknix/`.

## 1. Probe Android

Enable Developer Options → USB debugging. Connect USB. Accept the prompt.

```powershell
.\duo.ps1 probe
```

Check `out/probe/report.txt`:

- `ro.product.device` should be `RPDuo` (the Lite and flagship share the product name).
- `ro.board.platform` / `ro.hardware` should mention `sm6115`, `sm6125` or `bengal`.
- `ro.boot.verifiedbootstate` tells you whether the bootloader is locked.
- The partition list should include `abl_a`, `abl_b`, `boot_a`, `boot_b`.
- `ro.boot.slot_suffix` is `_a` or `_b`.

If `adb` is missing, `duo` can use Android platform-tools from `%LOCALAPPDATA%\Android\Sdk`,
`~/Android/Sdk`, or `ADB=...`; `duo probe` downloads platform-tools if necessary.

## 2. Try the non-destructive boot

```powershell
.\duo.ps1 boot
```

Watch the top panel. Success = a text console or Sway within ~30 s.

### If nothing appears

1. Wait 60 s; the first mount of a cold ext4 can be slow.
2. Check whether the device booted ROCKNIX instead: that means the ABL used the embedded initramfs
   and ignored our `initrd`. This is the main known unknown; see BOOT.md.
3. Re-enter fastboot (Power + Volume Down) and retry.
4. If `fastboot boot` is refused, go to the ABL/SD path (BOOT.md, Path B).

### If the kernel prints but the panel stays black

The kernel command line has `console=ttyMSM0,115200n8`; UART on the test pads is definitive.
Without one:

```sh
dmesg | grep -i -E 'panel|dsi|hx83112|wl818|backlight'
```

The top panel needs the HX83112A panel driver and the WL818S bridge/backlight; the bottom panel
needs `duolight-bottom-panel` and the bridge. These are in the ROCKNIX kernel/patchset we use.

## 3. First Linux boot checks

```sh
uname -a                          # 7.2.0
dmesg | grep -i -E 'panel|dsi|hx83112|wl818|ft5452|rsinput|ath10k|wcn|adsp|a610'
ls /sys/class/drm/                # card0-DSI-1, card0-DSI-2 expected
swaymsg -t get_outputs            # names, modes, transforms
cat /proc/bus/input/devices       # hx83112a, fts_ts, rsinput
ip link                           # wlan0, tailscale0
```

### Panels

```sh
swaymsg output DSI-2 enable
swaymsg output DSI-2 mode 1280x960 position 0,1080
swaymsg output DSI-1 transform 270    # if the top is portrait/upside down
```

Persist fixes in `/usr/local/bin/duo-layout` (`transform = 270` / `90`).

### Touch

```sh
swaymsg -t get_inputs
```

Map each panel:

```sh
swaymsg input "hx83112a" map_to_output DSI-1
swaymsg input "fts_ts" map_to_output DSI-2
```

`duo-layout` does this automatically by matching `bottom`/`secondary` in the device name. If the
names differ, add explicit lines to `/etc/sway/config`.

### Gamepad

```sh
systemctl status duo-inputd
journalctl -u duo-inputd -b
evtest /dev/input/eventX
```

`duo-inputd` grabs the first device with `BTN_SOUTH` whose name contains `retroid`, `rsinput` or
`gamepad`. It maps A/B/X/Y, d-pad, Start/Select, L1/R1 to keys. If it grabs the wrong device, edit
`find_device()`.

### Wi-Fi

```sh
nmcli device wifi list
nmcli device wifi connect "SSID" password "..."
dmesg | grep -i ath10k
```

The WCN3990 board files are at `/usr/lib/firmware/ath10k/WCN3990/hw1.0/retroid-duolite/`. If
`ath10k` cannot load firmware, check that path and `dmesg | grep -i firmware`.

### Bluetooth

```sh
bluetoothctl
dmesg | grep -i -E 'wcn3950|hci_qca'
```

Firmware is `retroid-duolite/cmnv13.bin`, copied from the nightly.

### Audio

```sh
aplay -l
alsamixer
speaker-test -c 2 -t sine -l 1
```

The UCM tree from the nightly is installed under `/usr/share/alsa/ucm2`. If the qrb4210 card has no
usable PCM, capture `aplay -l` and `dmesg | grep -i -E 'q6|apr|sound'`.

## 4. Tailscale and SSH

```sh
sudo systemctl enable --now tailscaled
sudo tailscale up --ssh --accept-routes
```

Or put a reusable auth key in `/etc/duo/tailscale.authkey` before first boot. Inbound password SSH is
disabled; use Tailscale SSH or `duo-keys add`.

## 5. Collect evidence

```sh
sudo duo collect --host duo      # from your PC, over ssh
# or on the device:
dmesg > /tmp/dmesg.txt
swaymsg -t get_outputs -r > /tmp/outputs.json
journalctl -b > /tmp/journal.txt
```

## 6. Make it persistent

Only after `fastboot boot` works and the session is usable, install to SD and flash the SM6115 ABL
(BOOT.md, Path B). Keep the stock ABL backup.
