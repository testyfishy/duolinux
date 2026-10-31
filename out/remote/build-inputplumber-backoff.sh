#!/bin/sh
# Build InputPlumber 0.82.0 with:
#   1. the axis-to-wheel patch (already in this repo)
#   2. an idle back-off in the source poll loop, instead of one poll per 2.5 ms
#
# The stock loop sleeps a fixed 2.5 ms between non-blocking reads per source and
# wakes a tokio worker each time; with two sources that measured ~10-11 % of a
# core at complete idle. Backing off to 16 ms after ~50 ms of no events keeps
# 400 Hz while the pad is being used and costs almost nothing when it is not.
set -u

apt-get install -y pkg-config libudev-dev >/tmp/ip-apt.log 2>&1
echo "deps exit=$?"

cd /root
rm -rf ip-src ip.tar.gz
curl -fsSL https://github.com/ShadowBlip/InputPlumber/archive/refs/tags/v0.82.0.tar.gz -o ip.tar.gz || exit 1
mkdir -p ip-src
tar xf ip.tar.gz -C ip-src --strip-components=1 || exit 1

cd ip-src
echo "=== axis-to-wheel patch"
patch -p1 < /root/0001-axis-to-wheel.patch || exit 1

echo "=== adaptive source poll back-off"
python3 - <<'PY' || exit 1
import pathlib, sys

path = pathlib.Path("src/input/source/mod.rs")
text = path.read_text()

anchor_state = """                loop {
                    let poll_time_start = Instant::now();
"""
new_state = """                // Consecutive polls that returned no events. Used to back the
                // poll rate off while the device is idle: a fixed 2.5 ms poll
                // woke a tokio worker 400 times a second per source for nothing.
                let mut empty_polls: u32 = 0;
                loop {
                    let poll_time_start = Instant::now();
"""
if anchor_state not in text:
    sys.exit("state anchor not found")
text = text.replace(anchor_state, new_state, 1)

anchor_events = """                    let events = implementation.poll()?;
"""
new_events = """                    let events = implementation.poll()?;
                    let poll_was_empty = events.is_empty();
"""
if anchor_events not in text:
    sys.exit("poll anchor not found")
text = text.replace(anchor_events, new_events, 1)

anchor_sleep = """                    let poll_time = poll_time_start.elapsed();
                    // Sleep up to the configured duration after polling timeout
                    if let Some(remaining) = self.options.poll_rate.checked_sub(poll_time) {
                        log::trace!("{:?}: Sleep time remaining: {remaining:?}", device_id);
                        thread::sleep(remaining);
                    } else {
                        log::trace!("{:?}: Total poll time: {poll_time:?} ", device_id);
                    }
"""
new_sleep = """                    let poll_time = poll_time_start.elapsed();

                    // Back off while the device is quiet: after 20 empty polls
                    // the sleep doubles every 20 further polls, capped at 16 ms,
                    // so an active device stays at the configured rate. Any
                    // event resets it immediately.
                    let mut sleep_for = self.options.poll_rate;
                    if poll_was_empty {
                        empty_polls = empty_polls.saturating_add(1);
                        if empty_polls > 20 {
                            let shift = ((empty_polls - 20) / 20).min(3);
                            sleep_for = sleep_for
                                .saturating_mul(1u32 << shift)
                                .min(Duration::from_millis(16));
                        }
                    } else {
                        empty_polls = 0;
                    }

                    // Sleep up to the configured duration after polling timeout
                    if let Some(remaining) = sleep_for.checked_sub(poll_time) {
                        log::trace!("{:?}: Sleep time remaining: {remaining:?}", device_id);
                        thread::sleep(remaining);
                    } else {
                        log::trace!("{:?}: Total poll time: {poll_time:?} ", device_id);
                    }
"""
if anchor_sleep not in text:
    sys.exit("sleep anchor not found")
text = text.replace(anchor_sleep, new_sleep, 1)

path.write_text(text)
print("patched src/input/source/mod.rs")
PY

echo "=== generating the back-off patch for the repo"
curl -fsSL https://raw.githubusercontent.com/ShadowBlip/InputPlumber/v0.82.0/src/input/source/mod.rs -o /tmp/mod.rs.orig || exit 1
diff -u /tmp/mod.rs.orig src/input/source/mod.rs > /root/0002-idle-backoff.patch
echo "patch bytes: $(wc -c < /root/0002-idle-backoff.patch)"

echo "=== build"
cargo build --release --locked -j4 >/tmp/ip-build.log 2>&1
echo "build exit=$?"
tail -8 /tmp/ip-build.log
ls -l target/release/inputplumber 2>&1
