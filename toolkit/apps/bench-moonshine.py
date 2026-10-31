"""Time Moonshine tiny (v2 layout) on the model's own test clips."""
import array
import inspect
import time
import wave

import sherpa_onnx

M = "/opt/duo-stt/models/sherpa-onnx-moonshine-tiny-en-int8"

print("signature:", inspect.signature(sherpa_onnx.OfflineRecognizer.from_moonshine_v2))

cfg = dict(
    preprocess=f"{M}/preprocess.onnx",
    encode=f"{M}/encode.int8.onnx",
    uncached_decode=f"{M}/uncached_decode.int8.onnx",
    cached_decode=f"{M}/cached_decode.int8.onnx",
    tokens=f"{M}/tokens.txt",
    num_threads=4,
    debug=False,
    provider="cpu",
)

t0 = time.perf_counter()
rec = sherpa_onnx.OfflineRecognizer.from_moonshine_v2(**cfg)
print(f"model load: {time.perf_counter() - t0:.2f} s")


def read(path):
    with wave.open(path) as f:
        sr = f.getframerate()
        data = f.readframes(f.getnframes())
    a = array.array("h")
    a.frombytes(data)
    return list(a), sr


for name in ("0.wav", "1.wav", "8k.wav"):
    samples, sr = read(f"{M}/test_wavs/{name}")
    dur = len(samples) / sr
    best = None
    text = ""
    for _ in range(3):
        t0 = time.perf_counter()
        s = rec.create_stream()
        s.accept_waveform(sr, samples)
        rec.decode_stream(s)
        dt = time.perf_counter() - t0
        best = dt if best is None else min(best, dt)
        text = s.result.text
    print(f"{name}: {dur:.2f}s audio -> {best * 1000:.0f} ms "
          f"(RTF {best / dur:.2f})  text={text!r}")
