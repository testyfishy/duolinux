#!/bin/bash
# Replace the 500 ms keyboard hack with a needs_poll() capability:
#
#   * TargetOutputDevice::needs_poll() defaults to true
#   * keyboard returns false (keys arrive as TargetCommand::WriteEvent)
#   * mouse returns true only while velocity (motion or wheel) is non-zero
#   * the target loop waits on the command channel when needs_poll() is false,
#     resets the interval when polling resumes, and uses Delay for missed ticks
#   * mouse dt is clamped, and last_poll is reset when velocity goes 0 -> non-0
#     so a first movement after idle cannot multiply a long gap
#
# ds5 keeps polling: its tick drains UHID output events and releases the
# QuickAccess chord; write_state() already skips identical state when closed.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$HOME/duo-build/inputplumber/src"
[ -d "$SRC" ] || { echo "build tree missing: run build-inputplumber.sh" >&2; exit 1; }
cd "$SRC"

python3 - <<'PY'
import pathlib, sys

# ---- src/input/target/mod.rs ------------------------------------------------
mod = pathlib.Path("src/input/target/mod.rs")
t = mod.read_text()

# 1. Revert the 500 ms keyboard options (patch 0003 v1) if present.
old_kb = '''            "keyboard" => {
                let device = KeyboardDevice::new()?;
                // Key presses arrive as TargetCommand::WriteEvent and wake this
                // loop through the rx.recv() branch, so the periodic poll only
                // calls an empty poll(). The generic 8 ms default costs ~125
                // wakeups/s at idle and buys no latency.
                let options = TargetDriverOptions {
                    poll_rate: Duration::from_millis(500),
                    buffer_size: 2048,
                };
                let driver = TargetDriver::new_with_options(id, device, dbus, options);
                Ok(Self::Keyboard(driver))
            }'''
new_kb = '''            "keyboard" => {
                let device = KeyboardDevice::new()?;
                let driver = TargetDriver::new(id, device, dbus);
                Ok(Self::Keyboard(driver))
            }'''
if old_kb in t:
    t = t.replace(old_kb, new_kb, 1)
    print("reverted 500 ms keyboard options")

# 2. Trait method.
anchor = '''    /// Returns the possible output events this device is capable of emitting
    #[allow(dead_code)]
    fn get_output_capabilities(&self) -> Result<Vec<OutputCapability>, OutputError> {'''
addition = '''    /// Whether this target needs to be polled on a timer.
    ///
    /// Devices that only emit in response to commands (a keyboard) or that have
    /// nothing to integrate (a mouse with zero velocity) return false. The
    /// target loop then waits for commands instead of waking at `poll_rate`.
    fn needs_poll(&self) -> bool {
        true
    }

'''
if "fn needs_poll(&self) -> bool" not in t:
    if anchor not in t:
        sys.exit("trait anchor not found")
    t = t.replace(anchor, addition + anchor, 1)

# 3. Interval setup.
anchor = "                let mut interval = tokio::time::interval(self.options.poll_rate);\n"
replacement = (
    "                let mut interval = tokio::time::interval(self.options.poll_rate);\n"
    "                // Do not fire a burst of ticks when polling resumes after an idle\n"
    "                // period; a single delayed tick is enough to integrate the gap.\n"
    "                interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);\n"
    "                let mut was_polling = false;\n"
)
if "was_polling" not in t:
    if anchor not in t:
        sys.exit("interval anchor not found")
    t = t.replace(anchor, replacement, 1)

# 4. Loop: wait on commands when the device does not need polling.
old_select = '''                    // Sleep for the configured duration or until a command is sent
                    tokio::select! {
                        _ = interval.tick() => (),
                        Some(cmd) = rx.recv() => {
                            let mut implementation = self.implementation.lock().unwrap();
                            let result = Self::process_command(&self.type_id, &mut composite_device, &metrics_tx, &mut implementation, cmd);
                            if let Err(e) = result {
                                log::debug!("Error processing received command: {e}");
                                break;
                            }
                        }
                    }'''
new_select = '''                    // Devices that emit only in response to commands (a keyboard)
                    // or that have nothing to integrate (a mouse at rest) must not
                    // be woken by a timer. Ask the implementation and either wait
                    // for a tick or block on the command channel.
                    let needs_poll = {
                        let implementation = self.implementation.lock().unwrap();
                        implementation.needs_poll()
                    };
                    if needs_poll && !was_polling {
                        interval.reset();
                    }
                    was_polling = needs_poll;

                    if needs_poll {
                        tokio::select! {
                            _ = interval.tick() => (),
                            Some(cmd) = rx.recv() => {
                                let mut implementation = self.implementation.lock().unwrap();
                                let result = Self::process_command(&self.type_id, &mut composite_device, &metrics_tx, &mut implementation, cmd);
                                if let Err(e) = result {
                                    log::debug!("Error processing received command: {e}");
                                    break;
                                }
                            }
                        }
                    } else if let Some(cmd) = rx.recv().await {
                        let mut implementation = self.implementation.lock().unwrap();
                        let result = Self::process_command(&self.type_id, &mut composite_device, &metrics_tx, &mut implementation, cmd);
                        if let Err(e) = result {
                            log::debug!("Error processing received command: {e}");
                            break;
                        }
                    } else {
                        break;
                    }'''
if "needs_poll()" not in t.split("let needs_poll")[-1]:
    pass
if old_select not in t:
    sys.exit("select anchor not found")
t = t.replace(old_select, new_select, 1)

mod.write_text(t)
print("patched target/mod.rs")

# ---- keyboard ---------------------------------------------------------------
kb = pathlib.Path("src/input/target/keyboard.rs")
t = kb.read_text()
old = "impl TargetOutputDevice for KeyboardDevice {}"
new = '''impl TargetOutputDevice for KeyboardDevice {
    /// Key presses arrive as TargetCommand::WriteEvent, which wakes the target
    /// loop through its command channel, so no timer is needed.
    fn needs_poll(&self) -> bool {
        false
    }
}'''
if old not in t:
    sys.exit("keyboard impl anchor not found")
kb.write_text(t.replace(old, new, 1))
print("patched keyboard.rs")

# ---- mouse ------------------------------------------------------------------
ms = pathlib.Path("src/input/target/mouse.rs")
t = ms.read_text()

t = t.replace("use std::{collections::HashMap, error::Error, time::Instant};",
              "use std::{\n    collections::HashMap,\n    error::Error,\n    time::{Duration, Instant},\n};", 1)

# needs_poll inside the TargetOutputDevice impl
anchor = "impl TargetOutputDevice for MouseDevice {\n"
addition = '''impl TargetOutputDevice for MouseDevice {
    /// Only the integrator needs a timer: with zero motion and wheel velocity
    /// there is nothing to advance, and events still arrive by command.
    fn needs_poll(&self) -> bool {
        self.state.mouse_velocity != (0.0, 0.0) || self.state.wheel_velocity != 0.0
    }

'''
if "fn needs_poll(&self) -> bool" not in t:
    if anchor not in t:
        sys.exit("mouse impl anchor not found")
    t = t.replace(anchor, addition, 1)

# clamp dt and skip work at rest
old_poll = '''        // Calculate the delta between the last poll
        let delta = self.last_poll.elapsed();
        self.last_poll = Instant::now();
'''
new_poll = '''        // Calculate the delta between the last poll. The target stops polling
        // while the mouse is at rest, so cap the gap: a long idle period must
        // not be multiplied by the velocity that just started.
        let mut delta = self.last_poll.elapsed();
        if delta > Duration::from_millis(50) {
            delta = Duration::from_millis(50);
        }
        self.last_poll = Instant::now();
'''
if old_poll not in t:
    sys.exit("mouse poll anchor not found")
t = t.replace(old_poll, new_poll, 1)

# reset last_poll when velocity transitions from rest to moving
old_update = '''        // Update the mouse velocity
        if let Some(x) = x {
            self.state.mouse_velocity.0 = x;
            log::trace!("Updating mouse state: {:?}", self.state.mouse_velocity);
        }
        if let Some(y) = y {
            self.state.mouse_velocity.1 = y;
            log::trace!("Updating mouse state: {:?}", self.state.mouse_velocity);
        }
'''
new_update = '''        // Update the mouse velocity
        let was_at_rest = self.state.mouse_velocity == (0.0, 0.0)
            && self.state.wheel_velocity == 0.0;
        if let Some(x) = x {
            self.state.mouse_velocity.0 = x;
            log::trace!("Updating mouse state: {:?}", self.state.mouse_velocity);
        }
        if let Some(y) = y {
            self.state.mouse_velocity.1 = y;
            log::trace!("Updating mouse state: {:?}", self.state.mouse_velocity);
        }
        if was_at_rest
            && (self.state.mouse_velocity != (0.0, 0.0)
                || self.state.wheel_velocity != 0.0)
        {
            // Polling resumes from this instant, not from the last poll before
            // the pointer went idle.
            self.last_poll = Instant::now();
        }
'''
if old_update not in t:
    sys.exit("mouse update anchor not found")
t = t.replace(old_update, new_update, 1)

ms.write_text(t)
print("patched mouse.rs")
PY

echo "=== regenerate 0003 patch"
for f in src/input/target/mod.rs src/input/target/keyboard.rs src/input/target/mouse.rs; do
    curl -fsSL "https://raw.githubusercontent.com/ShadowBlip/InputPlumber/v0.82.0/$f" -o "/tmp/orig-$(basename "$f")"
done
: > /tmp/0003.raw
for f in src/input/target/mod.rs src/input/target/keyboard.rs src/input/target/mouse.rs; do
    diff -u "/tmp/orig-$(basename "$f")" "$f" >> /tmp/0003.raw || true
done
python3 - <<'PY'
import pathlib, re
raw = pathlib.Path("/tmp/0003.raw").read_text().splitlines()
out = []
for line in raw:
    if line.startswith("--- "):
        name = line.split()[1].split("/")[-1]
        out.append(f"--- a/src/input/target/{name}")
    elif line.startswith("+++ "):
        name = line.split()[1].split("/")[-1]
        out.append(f"+++ b/src/input/target/{name}")
    else:
        out.append(line)
path = pathlib.Path("/mnt/c/Users/HTPC-Aran/Documents/Default Project/duolinux/out/inputplumber-fork/0003-needs-poll.patch")
path.write_text("\n".join(out).rstrip("\n") + "\n")
print("wrote", path.name, len(path.read_bytes()), "bytes")
PY
rm -f "$REPO/out/inputplumber-fork/0003-keyboard-idle-poll.patch"

bash "$REPO/toolkit/cross/build-inputplumber.sh"
