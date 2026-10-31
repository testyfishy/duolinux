# Daily use — Duo Lite

## First five minutes

The image ships with user `duo` and password `duo`.

```sh
passwd
nano /etc/duo/duo.conf     # add your server(s)
duo-keys                   # copy the device public key to your server
duo-tailscale login        # join your tailnet
```

## The cockpit

Top screen (1920×1080):

```
FLEET      per-host reachability, SSH latency, load average
LLM / GPU  GPU utilisation/VRAM/temperature, ollama/vLLM processes, top CPU
LOCAL      load, memory, temperature, battery, Wi-Fi, tailscale peers
```

Bottom screen (1280×960): large tiles for Terminal, SSH, LLM, Tailscale, Wi-Fi, Files, Keys,
Settings, Keyboard, Dashboard, Reboot, Power off.

### Controls

| Input | Action |
|---|---|
| D-pad | move |
| A | select / open |
| B | back |
| X | on-screen keyboard |
| Y | refresh |
| L1 / R1 | switch screens |
| Start | launcher |
| Select | keyboard |
| Mode | dashboard |

The face buttons are mapped to Enter/Esc/F2/F1, so they work in `nmtui`, `nnn`, `nano` and `tmux`.
The Lite's panels are 60 Hz; the UI does not animate, so this is fine.

### Touch

Tap a row in the cockpit. `wvkbd` provides a full keyboard; toggle with X or Select. The keyboard
appears on the focused output. If it covers the wrong screen, focus the bottom screen first.

## SSH and tmux

```sh
ssh server
tmux new -As main
```

`mosh` is installed for links that drop:

```sh
mosh server -- tmux new -As main
```

The cockpit reads hosts from `/etc/duo/duo.conf`:

```ini
[ssh]
hosts = server, root@192.168.1.20, desktop
```

Anything `ssh` accepts works, including aliases from `~/.ssh/config`.

## Tailscale

**Blocked on this kernel.** Tailscale's normal mode needs netfilter tables and policy routing, and
the ROCKNIX 7.2.0 kernel ships neither (`CONFIG_NF_TABLES` off, `ip_tables.ko` missing,
`CONFIG_IP_MULTIPLE_TABLES` unset). `tailscaled` exits in a restart loop. See
[TAILSCALE.md](TAILSCALE.md) for the evidence, the userspace-networking workaround and the kernel
options. The commands below work on a kernel that has those features.

```sh
tailscale status
tailscale netcheck
sudo tailscale up --ssh --accept-routes
```

Unattended provisioning: put a reusable auth key in `/etc/duo/tailscale.authkey` before first boot.
The file is mode 0600 and is read once by `duo-firstboot`. Delete it afterwards if you do not want the
key on the device.

Tailscale SSH (`--ssh`) is the easy way in from your laptop. Plain OpenSSH is also running; password
auth is off. Add keys with `duo-keys add`.

## LLM / GPU monitoring

The cockpit runs a command **on your server** over SSH. Edit it in `/etc/duo/duo.conf`:

```ini
[llm]
host = server
command = echo '== GPU'; nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader; echo '== OLLAMA'; ollama ps; echo '== TOP'; ps -eo pcpu,pmem,comm --sort=-pcpu | head -6
```

For AMD:

```sh
rocm-smi --showuse --showmemuse
```

For vLLM, add `curl -s localhost:8000/metrics | grep -E 'gpu_cache_usage|num_requests'`.

`duo-llm` gives the same view in a normal terminal, refreshed every five seconds.

## Wi-Fi

```sh
nmtui
# or
nmcli device wifi list
nmcli device wifi connect "SSID" password "..."
```

WCN3990 is 2.4/5 GHz Wi-Fi 5. `NetworkManager` is the only network manager; `systemd-resolved`
handles DNS.

## Files and USB drives

`nnn` is installed. `udisks2` mounts USB drives under `/media`. exFAT is supported; install
`ntfs-3g` if you need NTFS writes.

## Power and thermals

```sh
cat /sys/class/thermal/thermal_zone*/temp
cat /sys/class/hwmon/hwmon*/fan1_input 2>/dev/null
```

The fan is driven by the kernel's PWM/thermal zones; the DTS trips start at 45 °C. Suspend is not
trusted yet on this platform; prefer poweroff, the boot is fast.

## Updates

```sh
sudo apt update
sudo apt full-upgrade
sudo reboot
```

The kernel is not in Debian's archive. To update the hardware base, change `rocknix_version` in
`duo.json`, rebuild, and reinstall; or move to a source-built kernel (BUILD.md).

Back up:

```sh
sudo tar -C / -czf /home/duo/duo-backup.tgz etc/duo home/duo/.ssh var/lib/tailscale
```

## Troubleshooting

| Symptom | Check |
|---|---|
| No cockpit after boot | `cat ~/.local/state/duo/session.log`, `systemctl status duo-inputd` |
| One screen black | `swaymsg -t get_outputs`, `dmesg | grep -i -E 'panel|hx83112|wl818'` |
| Touch on wrong screen | `swaymsg -t get_inputs`, add `map_to_output` |
| No Wi-Fi | `dmesg | grep -i ath10k`, `ath10k/WCN3990/hw1.0/retroid-duolite/` |
| No Bluetooth | `dmesg | grep -i wcn3950`, `retroid-duolite/cmnv13.bin` |
| No audio | `aplay -l`, UCM under `/usr/share/alsa/ucm2`, `alsamixer` |
| Tailscale stuck | `journalctl -u tailscaled`, `tailscale netcheck` |
| Cockpit empty | `nano /etc/duo/duo.conf`, test `ssh server` manually |
| Boots ROCKNIX instead of Debian | ABL ignored the external initrd; see BOOT.md |
