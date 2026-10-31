# InputPlumber fork: axis to mouse wheel, and an idle poll back-off

Two patches, applied in order:

| Patch | What it fixes |
|---|---|
| `0001-axis-to-wheel.patch` | a stick pointed at a wheel target produced nothing |
| `0002-idle-backoff.patch` | the source loop polled every 2.5 ms even when idle, ~11 % of a core |

## Axis to wheel

InputPlumber 0.82.0 has wheel support for **buttons** (`MouseButton::WheelUp` and
the `mouse: {wheel: {direction: ...}}` profile target), but a stick pointed at a
wheel target produces nothing: the axis path returns
`TranslationError::NotImplemented`, and the mouse target has no wheel state to
integrate. This fork adds both, so a stick scrolls through the same pipeline the
left stick uses for pointer motion.

## What the patch changes

| File | Change |
|---|---|
| `src/config/capability_map.rs` | `MouseWheelCapability` gains `speed` (hi-res units per second) and `deadzone` |
| `src/input/event/value.rs` | new `translate_axis_to_wheel()`: returns a **velocity**, rescaled past the deadzone and curved so scrolling starts gradually |
| `src/input/target/mouse.rs` | `wheel_velocity` / `wheel_remainder` state, `REL_WHEEL_HI_RES` and `REL_HWHEEL_HI_RES` advertised, integration in `poll()` |

The rate is integrated against elapsed time, exactly like pointer motion, so
scroll speed does not depend on how often the controller reports. One detent is
120 hi-res units, and the legacy `REL_WHEEL` event is emitted alongside for
consumers that ignore hi-res events.

## Profile usage

```yaml
mapping:
  - name: Right stick scroll
    source_event: {gamepad: {axis: {name: RightStick}}}
    target_events:
      - mouse:
          wheel:
            direction: vertical   # vertical | horizontal | up | down | left | right
            speed: 1200.0         # hi-res units per second (10 detents/s)
            deadzone: 0.15
```

## Idle poll back-off

`src/input/source/mod.rs` runs one thread per source device and polls it every
`POLL_RATE` (2.5 ms) with a non-blocking read. On this device that is two
sources, ~800 reads/s, nearly all of them returning `EAGAIN`, and it measured
10-11 % of a core at complete idle (the stock binary does the same, so this is
not a regression from patch 0001).

The patch keeps the 2.5 ms rate while events are flowing and backs off after 20
empty polls: the sleep doubles every 20 further empty polls up to 16 ms, and any
event resets it immediately. Input latency at idle is at most 16 ms, well under a
frame, and force-feedback commands are drained in the same loop so they are
delayed by the same small amount.

## Building and installing

Cross-build on the PC; there is no reason to compile this on the handheld:

```sh
wsl -d Ubuntu-26.04 bash toolkit/cross/build-inputplumber.sh   # -> out/build/inputplumber
wsl -d Ubuntu-26.04 bash toolkit/cross/deploy.sh               # scp + restart, keeps .bak
```

`toolkit/cross/setup-root.sh` (run once as WSL root) installs
`gcc-aarch64-linux-gnu` and extracts the arm64 `libdbus-1-dev`, `libudev-dev` and
`libiio-dev` packages into `/srv/duo-arm64-sysroot`; `setup-rust.sh` adds the
`aarch64-unknown-linux-gnu` target. The build applies every `000*.patch` in this
directory.

Build natively on the device only if the cross toolchain cannot reproduce
something: `cargo build --release` there takes tens of minutes and the fat-LTO
link peaks near 2 GB.

## Installing without breaking the packaged files

InputPlumber ships udev, polkit and D-Bus files that its `Type=dbus` unit needs.
Do **not** run `make install`; put the binary beside them and override ExecStart:

```sh
sudo install -m 755 target/release/inputplumber /usr/local/bin/inputplumber
sudo mkdir -p /etc/systemd/system/inputplumber.service.d
sudo tee /etc/systemd/system/inputplumber.service.d/override.conf <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/local/bin/inputplumber
Environment=LOG_LEVEL=warn
EOF
sudo systemctl daemon-reload && sudo systemctl restart inputplumber
```

Rollback is `rm -rf /etc/systemd/system/inputplumber.service.d` and a restart.

## Publishing this fork

The patch here is a `git format-patch` from a local clone of tag `v0.82.0`:

```sh
git clone https://github.com/ShadowBlip/InputPlumber
cd InputPlumber
git checkout v0.82.0
git am /path/to/0001-axis-to-wheel.patch
git push origin HEAD:wheel-axis          # your fork
```

Then open a PR against upstream if you want it in the official tree; the feature
request is issue #591. `translate_button_to_wheel` already exists, so the
profile syntax is unchanged — this only fills in the missing axis path.
