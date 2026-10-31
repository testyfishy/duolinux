"""Sanity-check the pipeline with Whisper tiny.en through sherpa-onnx.
If this transcribes correctly, the empty output from the Zipformer model is a
model/checkpoint problem, not our code."""
import array
import os
import subprocess
import time
import wave

import sherpa_onnx

M = "/opt/duo-stt/models/sherpa-onnx-whisper-tiny.en"
URL = ("https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/"
       "sherpa-onnx-whisper-tiny.en.tar.bz2")

if not os.path.isdir(M):
    print("downloading whisper tiny.en...")
    subprocess.run(["curl", "-sL", "-o", "/tmp/wh.tar.bz2", URL], check=True)
    subprocess.run(["tar", "xjf", "/tmp/wh.tar.bz2", "-C", "/opt/duo-stt/models"], check=True)
    os.remove("/tmp/wh.tar.bz2")

inner = M          # the onnx files sit directly in the archive root
print("model dir:", inner, sorted(os.listdir(inner))[:8])


def read(path):
    with wave.open(path) as f:
        sr, n = f.getframerate(), f.getnframes()
        data = f.readframes(n)
    a = array.array("h")
    a.frombytes(data)
    return list(a), sr, n / sr


t0 = time.perf_counter()
rec = sherpa_onnx.OfflineRecognizer.from_whisper(
    encoder=f"{inner}/tiny.en-encoder.int8.onnx",
    decoder=f"{inner}/tiny.en-decoder.int8.onnx",
    tokens=f"{inner}/tiny.en-tokens.txt",
    num_threads=4,
    provider="cpu",
)
print(f"load: {time.perf_counter() - t0:.2f} s")

clips = "/opt/duo-stt/models/sherpa-onnx-zipformer-en-2023-06-26/test_wavs"
for name in ("0.wav", "8k.wav"):
    samples, sr, dur = read(os.path.join(clips, name))
    t0 = time.perf_counter()
    s = rec.create_stream()
    s.accept_waveform(sr, samples)
    rec.decode_stream(s)
    dt = time.perf_counter() - t0
    print(f"{name}: {dur:.2f}s -> {dt*1000:.0f} ms (RTF {dt/dur:.2f}) -> {s.result.text!r}")
