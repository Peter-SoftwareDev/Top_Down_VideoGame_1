"""Synthesize placeholder footstep sounds, 4 variations per floor material.

Writes assets/audio/steps/<material>_<n>.wav (22.05 kHz, mono, 16-bit).
Materials: stone, brick, straw, iron, water. Replace with recorded foley later; the game
picks up whatever WAVs are in that folder with these names.
Run: python3 tools/audio/footsteps.py
"""
import os, wave
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "audio", "steps")
SR = 22050

def bandpass(x, lo, hi):
    """FFT band-pass with soft edges (no SciPy needed)."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    mask = 1 / (1 + (lo / np.maximum(f, 1)) ** 4) * 1 / (1 + (f / hi) ** 4)
    return np.fft.irfft(X * mask, len(x))

def env(n, attack, decay):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-t / decay)

def stone(rng, dull=False):
    n = int(SR * 0.16)
    noise = rng.standard_normal(n)
    hi = 2400 if dull else 3600
    tap = bandpass(noise, 250, hi) * env(n, 0.001, 0.025)
    t = np.arange(n) / SR
    thump = np.sin(2 * np.pi * rng.uniform(90, 130) * t) * env(n, 0.002, 0.03) * 0.6
    scuff = bandpass(rng.standard_normal(n), 1500, 6000) * env(n, 0.01, 0.05) * 0.15
    return tap + thump + scuff

def straw(rng):
    n = int(SR * 0.3)
    out = np.zeros(n)
    for _ in range(rng.integers(18, 30)):      # many tiny crackles
        start = int(rng.uniform(0, 0.18) * SR)
        m = int(SR * rng.uniform(0.004, 0.012))
        if start + m < n:
            out[start:start + m] += rng.standard_normal(m) * np.hanning(m) * rng.uniform(0.3, 1.0)
    return bandpass(out, 1200, 7000) * env(n, 0.02, 0.12) * 0.8

def iron(rng):
    n = int(SR * 0.45)
    t = np.arange(n) / SR
    base = rng.uniform(380, 520)
    ring = sum(np.sin(2 * np.pi * base * r * t + rng.uniform(0, 6)) * a * np.exp(-t / d)
               for r, a, d in ((1.0, 0.5, 0.12), (2.76, 0.3, 0.08), (5.4, 0.2, 0.05), (8.9, 0.1, 0.03)))
    hit = bandpass(rng.standard_normal(n), 800, 8000) * env(n, 0.0005, 0.012)
    return (ring * 0.7 + hit) * env(n, 0.0008, 0.25)

def water(rng):
    n = int(SR * 0.35)
    t = np.arange(n) / SR
    slap = bandpass(rng.standard_normal(n), 400, 5000) * env(n, 0.003, 0.05)
    bubbles = np.zeros(n)
    for _ in range(rng.integers(3, 6)):        # rising "bloop" chirps
        start = int(rng.uniform(0.02, 0.15) * SR); m = int(SR * rng.uniform(0.03, 0.06))
        if start + m < n:
            tt = np.arange(m) / SR
            f0 = rng.uniform(500, 900)
            bubbles[start:start + m] += np.sin(2 * np.pi * (f0 * tt + 4000 * tt * tt)) * np.hanning(m) * 0.35
    return slap + bubbles

GEN = {"stone": lambda r: stone(r), "brick": lambda r: stone(r, dull=True), "straw": straw, "iron": iron, "water": water}
LEVEL = {"stone": 0.45, "brick": 0.4, "straw": 0.35, "iron": 0.55, "water": 0.5}

def write(path, x):
    x = x / (np.max(np.abs(x)) + 1e-9)
    fade = min(len(x), int(SR * 0.01))
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (x * 32767 * 0.9).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for mat, fn in GEN.items():
        for i in range(4):
            rng = np.random.default_rng(sum(map(ord, mat)) * 10 + i)   # same sounds every run
            write(os.path.join(OUT, f"{mat}_{i}.wav"), fn(rng) * LEVEL[mat])
    print("Wrote footsteps to", OUT)
