#!/usr/bin/env python3
"""Synthesises BreakBar's three sounds from scratch (no third-party audio, no licence strings).
Run from the repo root: python3 scripts/make-sounds.py"""
import math, random, struct, wave, pathlib

RATE = 44100
out = pathlib.Path(__file__).resolve().parent.parent / "App" / "Sounds"
out.mkdir(exist_ok=True)

def write(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    with wave.open(str(out / name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(32767 * 0.8 * s / peak)) for s in samples))

# ding: bell = a few inharmonic partials with exponential decay (1.6 s)
n = int(RATE * 1.6)
ding = [sum(a * math.exp(-t / d) * math.sin(2 * math.pi * f * t)
            for f, a, d in ((880, 1.0, 0.45), (1760, 0.5, 0.30), (2640, 0.25, 0.18), (1180, 0.3, 0.25)))
        for t in (i / RATE for i in range(n))]
write("ding.wav", ding)

# windup: a ratchet that speeds up and rises in pitch (1.0 s)
random.seed(7)
n = int(RATE * 1.0)
wind = [0.0] * n
pos, k = 0.0, 0
while pos < n:
    f = 400 + 1200 * (pos / n) ** 1.5                     # click pitch rises
    for j in range(int(RATE * 0.012)):
        if int(pos) + j < n:
            wind[int(pos) + j] += math.exp(-j / (RATE * 0.003)) * math.sin(2 * math.pi * f * j / RATE)
    pos += RATE * (0.12 - 0.095 * (pos / n))              # gaps shrink
write("windup.wav", wind)

# tick: one soft click, then silence, exactly 1 s so it loops once per second
n = RATE
tick = [0.0] * n
for j in range(int(RATE * 0.02)):
    tick[j] = math.exp(-j / (RATE * 0.004)) * (math.sin(2 * math.pi * 1500 * j / RATE) + 0.3 * (random.random() - 0.5))
write("tick.wav", tick)
print("wrote", sorted(p.name for p in out.glob("*.wav")))
