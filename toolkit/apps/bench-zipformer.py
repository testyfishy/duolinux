"""Benchmark a Zipformer transducer with the sherpa-onnx Python API."""
import array
import os
import subprocess
import sys
import time
import wave

import sherpa_onnx

M = "/opt/duo-stt/models/sherpa-onnx-zipformer-en-2023-06-26"
URL = ("https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/"
       "sherpa-onnx-zipformer-en-2023-06-26.tar.bz2")

if not os.path.isdir(M):
    print("downloading model...")
    subprocess.run(["curl", "-sL", "-o", "/tmp/zf.tar.bz2", URL], check=True)
    subprocess.run(["tar", "xjf", "/tmp/zf.tar.bz2", "-C", "/opt/duo-stt/models"], check=True)
    os.remove("/tmp/zf.tar.bz2")

print("model dir:", os.listdir(M)[:8])

cfg = dict(
    encoder=f"{M}/encoder-epoch-99-avg-1.onnx",
    decoder=f"{M}/decoder-epoch-99-avg-1.onnx",
    joiner=f"{M}/joiner-epoch-99-avg-1.onnx",
    tokens=f"{M}/tokens.txt",
    num_threads=4,
    provider="cpu",
    decoding_method="greedy_search",
)

t0 = time.perf_counter()
rec = sherpa_onnx.OfflineRecognizer.from_transducer(**cfg)
print(f"model load: {time.perf_counter() - t0:.2f} s")


def read(path):
    with wave.open(path) as f:
        sr = f.getframerate()
        data = f.readframes(f.getnframes())
    a = array.array("h")
    a.frombytes(data)
    return list(a), sr


clips = [f"{M}/test_wavs/{n}" for n in os.listdir(f"{M}/test_wavs")[:3]]
for path in clips:
    samples, sr = read(path)
    dur = len(samples) / sr
    best, text = None, ""
    for _ in range(3):
        t0 = time.perf_counter()
        s = rec.create_stream()
        s.accept_waveform(sr, samples)
        rec.decode_stream(s)
        dt = time.perf_counter() - t0
        best = dt if best is None else min(best, dt)
        text = s.result.text
    print(f"{os.path.basename(path)}: {dur:.2f}s audio -> {best*1000:.0f} ms "
          f"(RTF {best/dur:.2f}) text={text!r}")
