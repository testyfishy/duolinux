#!/usr/bin/env python3
"""Replay a temperature trace through the old and new fan control law.

The rewrite was supposed to change only polling, logging and sysfs writes, not
the control behaviour. This drives both implementations with the same trace and
reports where they differ, so "it looks fine" is not the evidence.
"""
import importlib.machinery
import importlib.util
import pathlib
import sys

DUO_FAN = pathlib.Path("/usr/local/bin/duo-fan")
if not DUO_FAN.exists():
    DUO_FAN = pathlib.Path(__file__).with_name("duo-fan")

spec = importlib.util.spec_from_loader("duofan", importlib.machinery.SourceFileLoader("duofan", str(DUO_FAN)))
duofan = importlib.util.module_from_spec(spec)
spec.loader.exec_module(duofan)

CURVE, PROFILE, CFG = duofan.load_profile()


class OldController:
    """The pre-rewrite loop: 8-sample deque, fixed 2 s poll, identical maths."""

    def __init__(self):
        from collections import deque
        self.samples = deque(maxlen=8)
        self.applied = self.target = 0
        self.running = False
        self.above = self.below = 0
        self.kick_until = 0.0
        self.avg_c = 0

    def step(self, temp_mc, now):
        cfg = CFG
        self.samples.append(temp_mc)
        avg_c = int(sum(self.samples) / len(self.samples) / 1000.0)
        self.avg_c = avg_c

        if avg_c >= cfg["start"]:
            self.above += 1
            self.below = 0
        elif avg_c <= cfg["stop"]:
            self.below += 1
            self.above = 0
        else:
            self.above = self.below = 0

        if not self.running and self.above >= 2:
            self.running = True
            self.kick_until = now + 1.0
            self.applied = cfg["minstart"]
        elif self.running and self.below >= 10:
            self.running = False
            self.applied = 0

        if self.running:
            wanted = max(cfg["minpwm"], duofan.interpolate(avg_c, CURVE))
            wanted = min(wanted, max(p for _, p in CURVE))
            if wanted > self.target + 2:
                self.target = wanted
            elif wanted < self.target - 2:
                self.target = wanted
            if now < self.kick_until:
                self.applied = cfg["minstart"]
            elif self.target > self.applied:
                self.applied = min(self.target, self.applied + cfg["step_up"])
            elif self.target < self.applied:
                self.applied = max(self.target, self.applied - cfg["step_down"])
            self.applied = max(self.applied, cfg["minstop"])
        else:
            self.applied = 0
            self.target = 0
        return self.applied


def trace(duration=900):
    """Idle, warm up to 80 C, plateau, cool down. Degrees C per second."""
    t = 0
    while t < duration:
        if t < 120:
            temp = 46.0
        elif t < 420:
            temp = 46.0 + (t - 120) / 300.0 * 34.0      # ramp to 80 C
        elif t < 600:
            temp = 80.0
        else:
            temp = max(45.0, 80.0 - (t - 600) / 30.0)   # cool down
        yield t, int(temp * 1000)
        t += 1


def main():
    old = OldController()
    new = duofan.FanController(CURVE, CFG)

    old_applied_at = {}
    for t, temp in trace():
        if t % 2 == 0:                       # the old loop polled every 2 s
            old_applied_at[t] = old.step(temp, float(t))

    new_at = {}
    t = 0.0
    samples = dict(trace())
    while t <= 900:
        temp = samples.get(int(t), 46000)
        new_at[int(t)] = new.step(temp, t)
        temp_c = temp // 1000
        t += 2.0 if (new.running or temp_c >= CFG["start"] - duofan.NEAR_START) else duofan.POLL_SLOW

    # compare the new value in force at each old 2 s tick
    diffs = []
    last_new = 0
    keys = sorted(new_at)
    i = 0
    for t in sorted(old_applied_at):
        while i < len(keys) and keys[i] <= t:
            last_new = new_at[keys[i]]
            i += 1
        if old_applied_at[t] > 0 or last_new > 0:
            diffs.append((t, old_applied_at[t], last_new))

    print(f"old start: {min((t for t, v in old_applied_at.items() if v), default=None)} s")
    print(f"new start: {min((t for t, v in new_at.items() if v), default=None)} s")
    print(f"old peak pwm: {max(old_applied_at.values())}, new peak pwm: {max(new_at.values())}")

    bad = [(t, o, n) for t, o, n in diffs if abs(o - n) > 8]
    print(f"ticks compared while running: {len(diffs)}, differing by >8 pwm: {len(bad)}")
    for t, o, n in bad[:8]:
        print(f"  t={t}s old={o} new={n}")
    worst = max((abs(o - n) for _, o, n in diffs), default=0)
    print(f"worst difference while running: {worst} pwm")
    return 0 if len(bad) == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
