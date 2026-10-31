"""Is ONNX Runtime working correctly on this CPU? Silero VAD is a tiny model
with an unambiguous answer: it should find speech in a LibriSpeech clip."""
import array
import os
import subprocess
import wave

import sherpa_onnx

D = "/opt/duo-stt/models/silero_vad.onnx"
URL = ("https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/"
       "silero_vad.onnx")

if not os.path.exists(D):
    print("downloading silero vad...")
    subprocess.run(["curl", "-sL", "-o", D, URL], check=True)

print("vad model:", os.path.getsize(D), "bytes")

cfg = sherpa_onnx.VadModelConfig()
cfg.silero_vad.model = D
cfg.silero_vad.min_silence_duration = 0.25
cfg.silero_vad.min_speech_duration = 0.25
cfg.sample_rate = 16000
cfg.num_threads = 2
vad = sherpa_onnx.VoiceActivityDetector(cfg, buffer_size_in_seconds=30)

wav = "/opt/duo-stt/models/sherpa-onnx-zipformer-en-2023-06-26/test_wavs/0.wav"
with wave.open(wav) as f:
    sr = f.getframerate()
    a = array.array("h")
    a.frombytes(f.readframes(f.getnframes()))
samples = list(a)
print(f"clip: {len(samples)/sr:.2f}s")

window = int(0.1 * sr)
speech = 0
for i in range(0, len(samples) - window, window):
    vad.accept_waveform(samples[i:i + window])
    while not vad.empty():
        seg = vad.front
        speech += (seg.end - seg.start) / sr
        vad.pop()
vad.flush()
while not vad.empty():
    seg = vad.front
    speech += (seg.end - seg.start) / sr
    vad.pop()

print(f"speech detected: {speech:.2f}s of {len(samples)/sr:.2f}s")
print("VERDICT:", "runtime OK" if speech > 0.5 else "runtime producing wrong results")
