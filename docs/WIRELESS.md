# Install over Wi-Fi, USB, or a card reader

The image is already built:

```
out\duolinux-duol.img
```

You need a **microSD card of 16 GB or more** in the Duo Lite. The image is 7.5 GiB; an “8 GB”
card is not big enough. A USB-C pendrive can carry the image, but the ABL boot path is simplest
with a microSD.

There are two manual moments I cannot do for you: enabling Android’s wireless-debugging pairing,
and tapping Retroid’s “Run script as root” entry. Everything else is scripted.

## Option A — Wi-Fi (preferred)

### On the Duo Lite

1. Connect the Duo to the same Wi-Fi network as this PC.
2. Open **Settings → About tablet**.
3. Tap **Build number** seven times. Enter your PIN if asked.
4. Open **Settings → System → Developer options**.
5. Turn on **Wireless debugging**.
6. Tap **Pair device with pairing code**.
7. Leave that dialog open. It shows an **IP address and port** and a **6-digit code**.

### On the PC

Open **PowerShell** in the project folder:

```powershell
cd "C:\path\to\duolinux"
```

Start the guided pairing:

```powershell
.\duo.ps1 wireless
```

It asks for two things:

```text
pairing endpoint (IP:PORT): 192.168.1.50:37123
6-digit pairing code: 123456
```

Use exactly what the pairing dialog shows. Then it asks for the **connect** endpoint:

```text
connect endpoint (IP:PORT): 192.168.1.50:5555
```

That is the IP:PORT on the main **Wireless debugging** screen, not the pairing dialog. The two ports
are usually different. If `adb connect` says `connected`, the serial is saved in
`out\device.json`.

Check it:

```powershell
.\duo.ps1 probe
```

You should see `RPDuo` in `out\probe\report.txt`.

### Push and install

Make sure the microSD card is inserted in the Duo. Keep the screen awake; Android may drop Wi-Fi
debugging when it sleeps.

```powershell
.\duo.ps1 install --via-adb --with-abl
```

This does three things:

1. Compresses `out\duolinux-duol.img` to a `.gz` (first run only).
2. Pushes the image, the SD writer, the ABL flasher, and `abl_signed-SM6115.elf` to
   `/sdcard/Download/duolinux/`.
3. Prints the two remaining taps.

The push is the slow part: roughly 1.5 GB over Wi-Fi. A 5 GHz network is much faster than 2.4 GHz.

### The two taps on the Duo

1. **Settings → Handheld Settings → Advanced → Run script as root**
2. Choose `Download/duolinux/install_sd.sh`
3. Wait for `Done.` It writes the microSD; Android is not touched.
4. Run the same menu again and choose `Download/duolinux/flash_abl.sh`.
   This backs up `abl_a`/`abl_b` to the same folder **before** flashing the SM6115 ABL.
5. Copy `abl_a.img` and `abl_b.img` off the device (USB, cloud, or `adb pull`).

Then power off. Hold **Volume Down** while powering on. In the ABL menu:

- **Boot mode → Linux**
- **Boot source → SD Card**
- **Start**

First boot may sit on a black screen for a while. If it does not come up, put the card in the PC and
read `duo-boot.log` from the FAT `ROCKNIX` partition. That log is written by our initramfs before it
tries to switch to Debian.

## Option B — USB cable (needed for the non-destructive test)

Wireless ADB cannot run `fastboot`. If you want to test the image without touching the ABL, use a
USB-C **data** cable.

1. On the Duo: **Settings → System → Developer options → USB debugging: On**.
2. Connect USB. Accept the **Allow USB debugging** prompt.
3. On the PC:

```powershell
cd "C:\path\to\duolinux"
.\duo.ps1 probe
.\duo.ps1 boot
```

`duo boot` reboots to the bootloader and runs `fastboot boot out\boot-duolinux-duol.img`. It writes
nothing. If Debian/Sway appears, the image is good; continue with the Wi-Fi or USB install.

If `fastboot boot` is refused, use the ABL/SD path (Option A or C).

## Option C — Card reader / pendrive

If you have a microSD card reader:

```powershell
.\duo.ps1 install --disk <n> --yes
```

Run PowerShell **as Administrator**. `duo install` lists removable disks, refuses the system disk,
refuses a card smaller than the image, and checks capacity.

Then flash the ABL over USB or Wi-Fi:

```powershell
.\duo.ps1 install --via-adb --with-abl
```

If you only have a USB-C pendrive, the ROCKNIX ABL can boot from USB storage: write the image with
Rufus/balenaEtcher to the pendrive, insert it through a USB-C OTG adapter, and set **Boot source →
USB** in the ABL menu. This is less tested than microSD; a cheap USB card reader is the safer route.

## If wireless ADB will not connect

- Phone and PC must be on the same subnet; guest Wi-Fi often blocks client-to-client traffic.
- Toggle Wireless debugging off/on and re-pair; the pairing port changes each time.
- Run `.\duo.ps1 adb devices` to see what adb sees.
- Run `.\duo.ps1 adb kill-server` then `.\duo.ps1 adb start-server`.
- If the connect port is not shown, use `.\duo.ps1 adb connect <IP>:5555` only after enabling
  `adb tcpip 5555` over USB; the normal Wireless debugging flow uses a random port.
- Keep the Duo awake during the 1.5 GB push.

## What I still cannot do remotely

- Tap Android’s pairing dialog or accept the RSA prompt.
- Run Retroid’s root script runner.
- Press the ABL menu buttons.

Those are the only physical actions left.
