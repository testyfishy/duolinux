#!/bin/bash
# Capture through PipeWire (which owns the card) in 5 s chunks, and stop as soon
# as a chunk contains speech. Leaves the winning clip at /tmp/speech.wav.
set -u
OUT=/tmp/speech.wav
LOG=/tmp/mic-listen.log
: > "$LOG"
rm -f "$OUT"

echo "=== source state" >> "$LOG"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 wpctl status' 2>/dev/null | sed -n '/Sources:/,/Filters:/p' >> "$LOG"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 wpctl get-volume @DEFAULT_AUDIO_SOURCE@' >> "$LOG" 2>&1

for i in $(seq 1 36); do          # up to 3 minutes
    su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 pw-record --rate 16000 --channels 1 --format s16 /tmp/chunk.wav' &
    rec=$!
    sleep 5
    kill "$rec" 2>/dev/null
    wait "$rec" 2>/dev/null

    stats=$(ffmpeg -hide_banner -i /tmp/chunk.wav -af volumedetect -f null - 2>&1)
    peak=$(echo "$stats" | sed -n 's/.*max_volume: \(-*[0-9.]*\) dB.*/\1/p')
    mean=$(echo "$stats" | sed -n 's/.*mean_volume: \(-*[0-9.]*\) dB.*/\1/p')
    echo "chunk $i: mean=${mean:-?} peak=${peak:-?}" >> "$LOG"

    # speech if the peak clears the noise floor by a good margin
    if [ -n "${peak:-}" ] && awk -v p="$peak" 'BEGIN { exit !(p > -30) }'; then
        cp /tmp/chunk.wav "$OUT"
        echo "SPEECH FOUND on chunk $i (peak $peak dB)" >> "$LOG"
        exit 0
    fi
done
echo "no speech captured" >> "$LOG"
