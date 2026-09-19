#!/usr/bin/env python3
"""Create a tiny synthetic library so the application works before real samples are imported."""
from __future__ import annotations

import csv
import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "data" / "library"
MANIFEST = LIBRARY / "manifest.csv"
RATE = 22_050

INSTRUMENTS = {
    "flute": [1.0, 0.18, 0.04, 0.02],
    "clarinet": [1.0, 0.06, 0.42, 0.04, 0.18],
    "violin": [1.0, 0.50, 0.32, 0.20, 0.12, 0.08],
    "cello": [1.0, 0.38, 0.20, 0.13, 0.08],
}
MIDIS = range(48, 85, 4)


def synthesize(midi: int, harmonics: list[float], duration: float = 1.1) -> list[float]:
    frequency = 440.0 * 2 ** ((midi - 69) / 12)
    count = int(duration * RATE)
    result = []
    for index in range(count):
        t = index / RATE
        attack = min(1.0, t / 0.025)
        release = min(1.0, (duration - t) / 0.15)
        envelope = max(0.0, attack * release) * math.exp(-0.35 * t)
        value = sum(weight * math.sin(2 * math.pi * frequency * (h + 1) * t)
                    for h, weight in enumerate(harmonics))
        result.append(0.28 * envelope * value / sum(harmonics))
    return result


def note_name(midi: int) -> str:
    names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    return f"{names[midi % 12]}{midi // 12 - 1}"


def main() -> None:
    LIBRARY.mkdir(parents=True, exist_ok=True)
    existing = list(LIBRARY.glob("demo_*.wav"))
    if existing and MANIFEST.exists():
        print(f"Demo library already exists ({len(existing)} samples).")
        return
    rows = []
    for instrument, harmonics in INSTRUMENTS.items():
        for midi in MIDIS:
            name = note_name(midi)
            filename = f"demo_{instrument}_{midi}.wav"
            samples = synthesize(midi, harmonics)
            with wave.open(str(LIBRARY / filename), "wb") as output:
                output.setnchannels(1)
                output.setsampwidth(2)
                output.setframerate(RATE)
                output.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(x * 32767)))) for x in samples))
            rows.append([filename, instrument, name, midi, "mf", "normal", "synthetic-demo"])
    with MANIFEST.open("w", newline="", encoding="utf-8") as output:
        writer = csv.writer(output, lineterminator="\n")
        writer.writerow(["path", "instrument", "note", "midi", "dynamic", "technique", "source"])
        writer.writerows(rows)
    print(f"Created {len(rows)} demo samples in {LIBRARY}")


if __name__ == "__main__":
    main()
