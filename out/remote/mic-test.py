#!/usr/bin/env python3
"""Find a capture device that actually produces audio (i.e. a working mic)."""
import array
import subprocess
import wave

DEVICES = ["hw:0,0", "hw:0,1", "hw:0,2"]

for dev in DEVICES:
    path = f"/tmp/mic-{dev.replace(':', '-').replace(',', '-')}.wav"
    rec = subprocess.run(
        ["timeout", "3", "arecord", "-D", dev, "-f", "S16_LE", "-r", "48000",
         "-c", "1", "-t", "wav", path],
        capture_output=True, text=True)
    note = (rec.stderr or "").strip().splitlines()
    try:
        with wave.open(path, "rb") as w:
            frames = w.readframes(w.getnframes())
            samples = array.array("h")
            samples.frombytes(frames[: len(frames) // 2 * 2])
            if not samples:
                print(f"{dev}: no samples ({note[-1] if note else 'empty'})")
                continue
            peak = max(max(samples), -min(samples))
            rms = (sum(s * s for s in samples) / len(samples)) ** 0.5
            print(f"{dev}: {len(samples)} samples  peak={peak}  rms={rms:.0f}")
    except Exception as exc:
        print(f"{dev}: FAILED {exc} {note[-1] if note else ''}")
