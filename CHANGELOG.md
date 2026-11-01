# Changelog

## v1.0

First finished snapshot: Debian 13 + Plasma 6.3 on the Retroid Pocket Duo Lite,
kernel 7.2.11-nf.

**Works:** both panels and touch, Plasma desktop across both screens, gamepad
input and mapping, on-screen keyboard, Wi-Fi, Bluetooth, lid suspend, fan
control, chargers and battery reporting, Tailscale (TUN mode), Moonlight
streaming, Jellyfin playback, audio playback.

**Known limits** (detail and reasons in `docs/STATE.md`): no microphone,
speaker level below stock Android, volume slider inert, hardware video decode
partial, and a cosmetic amp stop-check message.

**Kernel:** 7.2.11-nf, ROCKNIX's 79-patch SM6115 series rebased onto 7.2.11 with
netfilter enabled. Published in `kernel/patches/7.2.11/`.

**Tooling:** image builder (`duo`), cross-compile setup and scripts for arm64
binaries, the device configuration snapshot, and the diagnostic scripts.
