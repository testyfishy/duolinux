"""Why did the transducer return empty text? Try both encoder precisions and
print the clips' properties so nothing is guessed."""
import array
import os
import time
import wave

import sherpa_onnx

M = "/opt/duo-stt/models/sherpa-onnx-zipformer-en-2023-06-26"


def read(path):
    with wave.open(path) as f:
        sr, n = f.getframerate(), f.getnframes()
        data = f.readframes(n)
    a = array.array("h")
    a.frombytes(data)
    return list(a), sr, n / sr


for name in sorted(os.listdir(f"{M}/test_wavs")):
    if not name.endswith(".wav"):
        continue
    samples, sr, dur = read(f"{M}/test_wavs/{name}")
    peak = max(abs(x) for x in samples[:sr * 2]) if samples else 0
    print(f"{name}: {dur:.2f}s @ {sr} Hz, peak {peak}")

for enc in ("encoder-epoch-99-avg-1.onnx", "encoder-epoch-99-avg-1.int8.onnx"):
    print(f"\n=== {enc}")
    rec = sherpa_onnx.OfflineRecognizer.from_transducer(
        encoder=f"{M}/{enc}",
        decoder=f"{M}/decoder-epoch-99-avg-1.onnx",
        joiner=f"{M}/joiner-epoch-99-avg-1.onnx",
        tokens=f"{M}/tokens.txt",
        num_threads=4,
        provider="cpu",
        decoding_method="greedy_search",
    )
    for name in sorted(os.listdir(f"{M}/test_wavs")):
        if not name.endswith(".wav"):
            continue
        samples, sr, dur = read(f"{M}/test_wavs/{name}")
        t0 = time.perf_counter()
        s = rec.create_stream()
        s.accept_waveform(sr, samples)
        rec.decode_stream(s)
        dt = time.perf_counter() - t0
        print(f"  {name}: {dt*1000:.0f} ms (RTF {dt/dur:.2f}) -> {s.result.text!r}")
